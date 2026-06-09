type item = {id: string, name: string, count: int}
type itemQuery = {status: string}

let item = (id, name, count) => {id, name, count}

type loadable<'a> = TiliaQuery.loadable<'a> = Loading | Loaded('a) | NotFound
module Channel = TiliaQuery.Channel
type remoteApi<'a, 'query> = TiliaQuery.remote<'a, 'query>
type transport<'a, 'query> = {
  online: bool,
  fetch: ('query, Channel.t<array<'a>, string>) => option<unit => unit>,
  upsert: ('a, Channel.t<'a, TiliaQuery.upsertIssue<'a>>) => option<unit => unit>,
}
external asRemote: transport<'a, 'query> => remoteApi<'a, 'query> = "%identity"

module Papabase = {
  type api<'a, 'query> = remoteApi<'a, 'query>

  let make = (_table, id, remote, ~stale=?, ~gc=?, ~now=?, ~invalidates=?) =>
    TiliaQuery.make(
      ~id,
      ~remote,
      ~stale?,
      ~gc?,
      ~now?,
      ~invalidates?,
      (),
    )
}

module Store = {
  type t<'a> = dict<'a>

  let fromItems = items => {
    let dict = Dict.make()
    items->Array.forEach(item => Dict.set(dict, item.id, item))
    dict
  }

  let get = (dict, id) =>
    switch Dict.get(dict, id) {
    | Some(value) => value
    | None => failwith("Expected task in store")
    }

  let byStatus = (dict, status) =>
    Dict.toArray(dict)
    ->Array.map(((_, value)) => value)
    ->Array.filter(item => item.name == status)
}

type writeOutcome =
  | Success(item)
  | Retry(item)
  | Drop
  | Reject(string)

type heldWrite = {
  value: item,
  outcome: writeOutcome,
  channel: Channel.t<item, TiliaQuery.upsertIssue<item>>,
}

type network = {mutable value: bool}

type remote = {
  api: Papabase.api<item, itemQuery>,
  network: network,
  activeFetches: ref<int>,
  doneFetches: ref<int>,
  offlineFetches: ref<int>,
  upsertCalls: ref<int>,
  syncedWrites: ref<array<item>>,
  rejectedWrites: ref<int>,
  activeChannels: ref<array<Channel.t<array<item>, string>>>,
  heldWrites: ref<array<heldWrite>>,
  pausedWrites: ref<bool>,
  outcomes: ref<dict<array<writeOutcome>>>,
  remoteStore: ref<Store.t<item>>,
}

module Runtime = {
  @module("vitest") @scope("vi") external useFakeTimers: unit => unit = "useFakeTimers"
}

@send external splice: (array<'a>, int, int) => array<'a> = "splice"

let pushOutcome = (remote, id, outcome) =>
  switch Dict.get(remote.outcomes.contents, id) {
  | Some(values) => Dict.set(remote.outcomes.contents, id, [...values, outcome])
  | None => Dict.set(remote.outcomes.contents, id, [outcome])
  }

let takeHeld = (remote, index) =>
  switch remote.heldWrites.contents[index] {
  | Some(held) => {
      let next = [...remote.heldWrites.contents]
      ignore(splice(next, index, 1))
      remote.heldWrites := next
      Some(held)
    }
  | None => None
  }

let makeRemote = (
  ~online=true,
  (),
) => {
  let network: network = Tilia.tilia({value: online})
  let activeFetches = ref(0)
  let doneFetches = ref(0)
  let offlineFetches = ref(0)
  let upsertCalls = ref(0)
  let syncedWrites = ref([])
  let rejectedWrites = ref(0)
  let activeChannels = ref([])
  let heldWrites = ref([])
  let pausedWrites = ref(false)
  let outcomes = ref(Dict.make())
  let remoteStore = ref(Dict.make())

  let fetch = (query: itemQuery, channel: Channel.t<array<item>, string>) => {
    if network.value {
      switch query.status {
      | "active" => activeFetches := activeFetches.contents + 1
      | "done" => doneFetches := doneFetches.contents + 1
      | _ => ()
      }
      let rows = Store.byStatus(remoteStore.contents, query.status)
      switch query.status {
      | "active" => activeChannels := [...activeChannels.contents, channel]
      | _ => ()
      }
      channel.emit(rows)
      None
    } else {
      offlineFetches := offlineFetches.contents + 1
      channel.fail("offline")
      None
    }
  }

  let pullOutcome = (value: item) =>
    switch Dict.get(outcomes.contents, value.id) {
  | Some(values) =>
    switch values[0] {
    | Some(head) => {
        let tail = [...values]
        ignore(splice(tail, 0, 1))
        Dict.set(outcomes.contents, value.id, tail)
        head
      }
    | None => Success(value)
    }
    | _ => Success(value)
    }

  let applyOutcome = (channel: Channel.t<item, TiliaQuery.upsertIssue<item>>, outcome: writeOutcome) =>
    switch outcome {
    | Success(saved) => {
        Dict.set(remoteStore.contents, saved.id, saved)
        syncedWrites := [...syncedWrites.contents, saved]
        channel.emit(saved)
      }
    | Retry(server) => {
        Dict.set(remoteStore.contents, server.id, server)
        channel.fail(Conflict(server))
      }
    | Drop => channel.fail(Offline)
    | Reject(message) => {
        rejectedWrites := rejectedWrites.contents + 1
        channel.fail(Rejected(message))
      }
    }

  let transport: transport<item, itemQuery> = Tilia.tilia({
    online: Tilia.computed(() => network.value),
    fetch,
    upsert: (value: item, channel: Channel.t<item, TiliaQuery.upsertIssue<item>>) => {
      upsertCalls := upsertCalls.contents + 1
      if network.value {
        let outcome = pullOutcome(value)
        if pausedWrites.contents {
          heldWrites := [...heldWrites.contents, {value, outcome, channel}]
        } else {
          applyOutcome(channel, outcome)
        }
      } else {
        channel.fail(Offline)
      }
      None
    },
  })
  let api: Papabase.api<item, itemQuery> = asRemote(transport)

  let remote = {
    api,
    network,
    activeFetches,
    doneFetches,
    offlineFetches,
    upsertCalls,
    syncedWrites,
    rejectedWrites,
    activeChannels,
    heldWrites,
    pausedWrites,
    outcomes,
    remoteStore,
  }
  remote
}

type world = {
  clock: ref<float>,
  remote: remote,
  items: TiliaQuery.t<item, itemQuery>,
}

let makeWorld = () => {
  Runtime.useFakeTimers()
  let clock = ref(0.0)
  let remote = makeRemote()

  let id = (item: item) => item.id

  let items = Papabase.make(
    "items",
    id,
    remote.api,
    ~stale=30.0,
    ~gc=300.0,
    ~now=() => clock.contents,
    ~invalidates=(query, changed) => query.status == "active" || query.status == changed.name,
  )

  {clock, remote, items}
}

let seed = (w, items) => {
  w.remote.remoteStore := Store.fromItems(items)
  w.remote.activeFetches := 0
  w.remote.doneFetches := 0
  w.remote.offlineFetches := 0
  w.remote.upsertCalls := 0
  w.remote.syncedWrites := []
  w.remote.rejectedWrites := 0
  w.remote.activeChannels := []
  w.remote.heldWrites := []
  w.remote.pausedWrites := false
  w.remote.outcomes := Dict.make()
}

let setNetwork = (w, online) => w.remote.network.value = online

let remoteTask = (w, id) => Store.get(w.remote.remoteStore.contents, id)

let queueConflict = (w, id, status, count) => pushOutcome(w.remote, id, Retry(item(id, status, count)))

let queueRejected = (w, id, message) => pushOutcome(w.remote, id, Reject(message))

let queueOffline = (w, id) => pushOutcome(w.remote, id, Drop)

let pauseWrites = (w, paused) => w.remote.pausedWrites := paused

let emitHeldWrite = (w, index, count) =>
  switch takeHeld(w.remote, index) {
  | Some(held) => {
      let value = item(held.value.id, held.value.name, count)
      Dict.set(w.remote.remoteStore.contents, value.id, value)
      w.remote.syncedWrites := [...w.remote.syncedWrites.contents, value]
      held.channel.emit(value)
    }
  | None => ()
  }

let heldWrites = w => w.remote.heldWrites.contents->Array.length

let emitActiveChannel = (w, index, count) =>
  switch w.remote.activeChannels.contents[index] {
  | Some(channel) => channel.emit([item("todo-1", "active", count)])
  | None => ()
  }
