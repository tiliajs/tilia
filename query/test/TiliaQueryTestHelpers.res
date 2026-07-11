type item = {id: string, name: string, count: int}
type itemQuery = {status: string}

let item = (id, name, count) => {id, name, count}

@tag("state")
type loadable<'a> = TiliaQuery.loadable<'a> =
  | @as("loading") Loading
  | @as("loaded") Loaded({data: 'a})
  | @as("notFound") NotFound
module Channel = TiliaQuery.Channel
type remoteApi<'a, 'query> = TiliaQuery.remote<'a, 'query>
type transport<'a, 'query> = {
  online: bool,
  fetch: ('query, Channel.fetch<'a>) => option<unit => unit>,
  upsert: ('a, Channel.write<'a>) => unit,
  remove: ('a, Channel.write<'a>) => unit,
}
external asRemote: transport<'a, 'query> => remoteApi<'a, 'query> = "%identity"

module Papabase = {
  type api<'a, 'query> = remoteApi<'a, 'query>

  let make = (_table, id, remote, ~local=?, ~stale=?, ~gc=?, ~now=?, ~matches=?, ~sort=?) =>
    TiliaQuery.make({
      id,
      remote,
      local: ?local,
      stale: ?stale,
      gc: ?gc,
      now: ?now,
      matches: ?matches,
      sort: ?sort,
    })
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

type fetchOutcome =
  | CoveredFetch
  | FailFetch(string)

type heldWrite = {
  value: item,
  outcome: writeOutcome,
  channel: Channel.write<item>,
}

type network = {mutable value: bool}

type localRow = {item: item, dirty: bool, deleted: bool}

type remote = {
  api: Papabase.api<item, itemQuery>,
  localApi: TiliaQuery.store<item, itemQuery>,
  network: network,
  activeFetches: ref<int>,
  doneFetches: ref<int>,
  offlineFetches: ref<int>,
  localFetches: ref<int>,
  upsertCalls: ref<int>,
  removeCalls: ref<int>,
  syncedWrites: ref<array<item>>,
  rejectedWrites: ref<int>,
  activeChannels: ref<array<Channel.fetch<item>>>,
  heldWrites: ref<array<heldWrite>>,
  heldRemoves: ref<array<heldWrite>>,
  pausedWrites: ref<bool>,
  outcomes: ref<dict<array<writeOutcome>>>,
  nextFetches: ref<dict<fetchOutcome>>,
  remoteStore: ref<Store.t<item>>,
  localStore: ref<dict<localRow>>,
  queryStore: ref<dict<TiliaQuery.queryRecord>>,
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
  let localFetches = ref(0)
  let upsertCalls = ref(0)
  let removeCalls = ref(0)
  let syncedWrites = ref([])
  let rejectedWrites = ref(0)
  let activeChannels = ref([])
  let heldWrites = ref([])
  let heldRemoves = ref([])
  let pausedWrites = ref(false)
  let outcomes = ref(Dict.make())
  let nextFetches: ref<dict<fetchOutcome>> = ref(Dict.make())
  let remoteStore = ref(Dict.make())
  let localStore: ref<dict<localRow>> = ref(Dict.make())
  let queryStore: ref<dict<TiliaQuery.queryRecord>> = ref(Dict.make())

  let fetch = (query: itemQuery, channel: Channel.fetch<item>) => {
    if network.value {
      switch query.status {
      | "active" => activeFetches := activeFetches.contents + 1
      | "done" => doneFetches := doneFetches.contents + 1
      | _ => ()
      }
      switch query.status {
      | "active" => activeChannels := [...activeChannels.contents, channel]
      | _ => ()
      }
      switch Dict.get(nextFetches.contents, query.status) {
      | Some(CoveredFetch) => {
          Dict.delete(nextFetches.contents, query.status)
          channel.covered()
        }
      | Some(FailFetch(message)) => {
          Dict.delete(nextFetches.contents, query.status)
          channel.fail(message)
        }
      | None => channel.set(Store.byStatus(remoteStore.contents, query.status))
      }
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

  let applyOutcome = (channel: Channel.write<item>, outcome: writeOutcome) =>
    switch outcome {
    | Success(saved) => {
        Dict.set(remoteStore.contents, saved.id, saved)
        syncedWrites := [...syncedWrites.contents, saved]
        channel.saved(saved)
      }
    | Retry(server) => {
        Dict.set(remoteStore.contents, server.id, server)
        channel.conflict(server)
      }
    | Drop => channel.offline()
    | Reject(message) => {
        rejectedWrites := rejectedWrites.contents + 1
        channel.rejected(message)
      }
    }

  let applyRemoveOutcome = (channel: Channel.write<item>, outcome: writeOutcome) =>
    switch outcome {
    | Success(value) => {
        Dict.delete(remoteStore.contents, value.id)
        syncedWrites := [...syncedWrites.contents, value]
        channel.saved(value)
      }
    | Retry(server) => {
        Dict.set(remoteStore.contents, server.id, server)
        channel.conflict(server)
      }
    | Drop => channel.offline()
    | Reject(message) => {
        rejectedWrites := rejectedWrites.contents + 1
        channel.rejected(message)
      }
    }

  let transport: transport<item, itemQuery> = Tilia.tilia({
    online: Tilia.computed(() => network.value),
    fetch,
    upsert: (value: item, channel: Channel.write<item>) => {
      upsertCalls := upsertCalls.contents + 1
      if network.value {
        let outcome = pullOutcome(value)
        if pausedWrites.contents {
          heldWrites := [...heldWrites.contents, {value, outcome, channel}]
        } else {
          applyOutcome(channel, outcome)
        }
      } else {
        channel.offline()
      }
    },
    remove: (value: item, channel: Channel.write<item>) => {
      removeCalls := removeCalls.contents + 1
      if network.value {
        let outcome = pullOutcome(value)
        if pausedWrites.contents {
          heldRemoves := [...heldRemoves.contents, {value, outcome, channel}]
        } else {
          applyRemoveOutcome(channel, outcome)
        }
      } else {
        channel.offline()
      }
    },
  })
  let api: Papabase.api<item, itemQuery> = asRemote(transport)

  let localApi: TiliaQuery.store<item, itemQuery> = {
    fetch: (query, channel) => {
      localFetches := localFetches.contents + 1
      let rows =
        Dict.valuesToArray(localStore.contents)
        ->Array.filter(row => !row.deleted && row.item.name == query.status)
        ->Array.map(row => row.item)
      channel.set(rows)
      None
    },
    save: (item, dirty) => Dict.set(localStore.contents, item.id, {item, dirty, deleted: false}),
    remove: (item, dirty) =>
      if dirty {
        Dict.set(localStore.contents, item.id, {item, dirty: true, deleted: true})
      } else {
        Dict.delete(localStore.contents, item.id)
      },
    dirty: () =>
      Promise.resolve(
        Dict.valuesToArray(localStore.contents)
        ->Array.filter(row => row.dirty)
        ->Array.map((row): TiliaQuery.write<item> => {value: row.item, deleted: row.deleted}),
      ),
    queries: () => Promise.resolve(Dict.valuesToArray(queryStore.contents)),
    saveQuery: record => Dict.set(queryStore.contents, record.key, record),
    removeQuery: key => Dict.delete(queryStore.contents, key),
  }

  let remote = {
    api,
    localApi,
    network,
    activeFetches,
    doneFetches,
    offlineFetches,
    localFetches,
    upsertCalls,
    removeCalls,
    syncedWrites,
    rejectedWrites,
    activeChannels,
    heldWrites,
    heldRemoves,
    pausedWrites,
    outcomes,
    nextFetches,
    remoteStore,
    localStore,
    queryStore,
  }
  remote
}

type world = {
  clock: ref<float>,
  remote: remote,
  mutable items: TiliaQuery.t<item, itemQuery>,
}

let id = (item: item) => item.id

let makeItems = (clock, remote) =>
  Papabase.make(
    "items",
    id,
    remote.api,
    ~local=remote.localApi,
    ~stale=30.0,
    ~gc=300.0,
    ~now=() => clock.contents,
    ~matches=(query, changed) => changed.name == query.status,
    ~sort=(a, b) => String.localeCompare(a.id, b.id),
  )

let makeWorld = () => {
  Runtime.useFakeTimers()
  let clock = ref(0.0)
  let remote = makeRemote()
  {clock, remote, items: makeItems(clock, remote)}
}

let restart = w => {
  w.items = makeItems(w.clock, w.remote)
  // Yield so the boot dirty() load settles before the next step runs.
  Promise.resolve()->Promise.then(() => Promise.resolve())
}

let seed = (w, items) => {
  w.remote.remoteStore := Store.fromItems(items)
  w.remote.activeFetches := 0
  w.remote.doneFetches := 0
  w.remote.offlineFetches := 0
  w.remote.localFetches := 0
  w.remote.upsertCalls := 0
  w.remote.removeCalls := 0
  w.remote.syncedWrites := []
  w.remote.rejectedWrites := 0
  w.remote.activeChannels := []
  w.remote.heldWrites := []
  w.remote.heldRemoves := []
  w.remote.pausedWrites := false
  w.remote.outcomes := Dict.make()
  w.remote.nextFetches := Dict.make()
  w.remote.localStore := Dict.make()
  w.remote.queryStore := Dict.make()
}

let setNetwork = (w, online) => w.remote.network.value = online

let remoteTask = (w, id) => Store.get(w.remote.remoteStore.contents, id)

let seedLocal = (w, id, status, count, dirty) =>
  Dict.set(w.remote.localStore.contents, id, {item: item(id, status, count), dirty, deleted: false})

let seedLocalTombstone = (w, id, status, count) =>
  Dict.set(w.remote.localStore.contents, id, {item: item(id, status, count), dirty: true, deleted: true})

let localTask = (w, id) =>
  switch Dict.get(w.remote.localStore.contents, id) {
  | Some(row) => row
  | None => failwith("Expected task in local store")
  }

let localRow = (w, id) => Dict.get(w.remote.localStore.contents, id)

let remoteRow = (w, id) => Dict.get(w.remote.remoteStore.contents, id)

let deleteOnServer = (w, id) => Dict.delete(w.remote.remoteStore.contents, id)

let seedQueryRecord = (w, key, ids) =>
  Dict.set(w.remote.queryStore.contents, key, ({key, ids, fetched: 0.0}: TiliaQuery.queryRecord))

let queryRecord = (w, key) => Dict.get(w.remote.queryStore.contents, key)

let localFetchCount = w => w.remote.localFetches.contents

let queueConflict = (w, id, status, count) => pushOutcome(w.remote, id, Retry(item(id, status, count)))

let queueRejected = (w, id, message) => pushOutcome(w.remote, id, Reject(message))

let queueOffline = (w, id) => pushOutcome(w.remote, id, Drop)

let queueCoveredFetch = (w, status) =>
  Dict.set(w.remote.nextFetches.contents, status, CoveredFetch)

let queueFailFetch = (w, status, message) =>
  Dict.set(w.remote.nextFetches.contents, status, FailFetch(message))

let pauseWrites = (w, paused) => w.remote.pausedWrites := paused

let takeHeldRemove = (remote, index) =>
  switch remote.heldRemoves.contents[index] {
  | Some(held) => {
      let next = [...remote.heldRemoves.contents]
      ignore(splice(next, index, 1))
      remote.heldRemoves := next
      Some(held)
    }
  | None => None
  }

let settleHeldRemove = (w, index) =>
  switch takeHeldRemove(w.remote, index) {
  | Some(held) => {
      Dict.delete(w.remote.remoteStore.contents, held.value.id)
      w.remote.syncedWrites := [...w.remote.syncedWrites.contents, held.value]
      held.channel.saved(held.value)
    }
  | None => ()
  }

let settleHeldWrite = (w, index, count) =>
  switch takeHeld(w.remote, index) {
  | Some(held) => {
      let value = item(held.value.id, held.value.name, count)
      Dict.set(w.remote.remoteStore.contents, value.id, value)
      w.remote.syncedWrites := [...w.remote.syncedWrites.contents, value]
      held.channel.saved(value)
    }
  | None => ()
  }

let heldWrites = w => w.remote.heldWrites.contents->Array.length

let setActiveChannel = (w, index, count) =>
  switch w.remote.activeChannels.contents[index] {
  | Some(channel) => channel.set([item("todo-1", "active", count)])
  | None => ()
  }
