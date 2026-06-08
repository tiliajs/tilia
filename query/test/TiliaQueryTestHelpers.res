type item = {id: string, name: string, count: int}
type itemQuery = {status: string}

let item = (id, name, count) => {id, name, count}

type loadable<'a> = TiliaQuery.loadable<'a> = Loading | Loaded('a) | NotFound
type channel<'a> = TiliaQuery.channel<'a>

module Papabase = {
  type api<'a, 'query> = {
    fetch: ('query, channel<array<'a>>) => option<unit => unit>,
    upsert: ('a, channel<unit>) => option<unit => unit>,
  }

  let make = (_table, id, api, ~stale=?, ~gc=?, ~now=?, ~invalidates=?) =>
    TiliaQuery.make(
      ~id,
      ~fetch=api.fetch,
      ~upsert=api.upsert,
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

type remote = {
  api: Papabase.api<item, itemQuery>,
  online: ref<bool>,
  activeFetches: ref<int>,
  doneFetches: ref<int>,
  offlineFetches: ref<int>,
  pendingWrites: ref<array<item>>,
  syncedWrites: ref<array<item>>,
  activeChannels: ref<array<channel<array<item>>>>,
  localStore: ref<Store.t<item>>,
  remoteStore: ref<Store.t<item>>,
  syncPending: unit => unit,
}

module Runtime = {
  @module("vitest") @scope("vi") external useFakeTimers: unit => unit = "useFakeTimers"
}

let makeRemote = (
  ~online=true,
  (),
) => {
  let online = ref(online)
  let activeFetches = ref(0)
  let doneFetches = ref(0)
  let offlineFetches = ref(0)
  let pendingWrites = ref([])
  let syncedWrites = ref([])
  let activeChannels = ref([])
  let localStore = ref(Dict.make())
  let remoteStore = ref(Dict.make())

  let fetch = (query: itemQuery, channel: channel<array<item>>) => {
    if online.contents {
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
      let rows = Store.byStatus(localStore.contents, query.status)
      channel.emit(rows)
      None
    }
  }

  let upsert = (value: item, channel: channel<unit>) => {
    Dict.set(localStore.contents, value.id, value)
    if online.contents {
      Dict.set(remoteStore.contents, value.id, value)
      syncedWrites := [...syncedWrites.contents, value]
    } else {
      pendingWrites := [...pendingWrites.contents, value]
    }
    channel.emit(())
    None
  }

  let syncPending = () => {
    if online.contents {
      pendingWrites.contents->Array.forEach(value => {
        Dict.set(remoteStore.contents, value.id, value)
        syncedWrites := [...syncedWrites.contents, value]
      })
      pendingWrites := []
    }
  }

  {
    api: {fetch, upsert},
    online,
    activeFetches,
    doneFetches,
    offlineFetches,
    pendingWrites,
    syncedWrites,
    activeChannels,
    localStore,
    remoteStore,
    syncPending,
  }
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
  let initial = Store.fromItems(items)
  w.remote.localStore := initial
  w.remote.remoteStore := Store.fromItems(items)
  w.remote.activeFetches := 0
  w.remote.doneFetches := 0
  w.remote.offlineFetches := 0
  w.remote.pendingWrites := []
  w.remote.syncedWrites := []
  w.remote.activeChannels := []
}

let remoteTask = (w, id) => Store.get(w.remote.remoteStore.contents, id)

let emitActiveChannel = (w, index, count) =>
  switch w.remote.activeChannels.contents[index] {
  | Some(channel) => channel.emit([item("todo-1", "active", count)])
  | None => ()
  }
