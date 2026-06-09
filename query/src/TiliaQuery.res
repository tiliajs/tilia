type loadable<'a> =
  | Loading
  | Loaded('a)
  | NotFound

module Channel = {
  type state =
    | Live
    | Cancelled

  type t<'a, 'issue> = {
    state: state,
    emit: 'a => unit,
    fail: 'issue => unit,
  }
}

type upsertIssue<'a> =
  | Offline
  | Conflict('a)
  | Rejected(string)

module Dict = {
  type t<'a>
  let make: unit => t<'a> = %raw(`() => ({})`)
  @val @scope("Reflect") external get: (t<'a>, string) => nullable<'a> = "get"
  @val @scope("Reflect") external getKnown: (t<'a>, string) => 'a = "get"
  @val @scope("Reflect") external set: (t<'a>, string, 'a) => unit = "set"
  @val @scope("Reflect") external delete: (t<'a>, string) => unit = "deleteProperty"
  @val @scope("Object") external keys: t<'a> => array<string> = "keys"
}

type dict<'a>

module Object = {
  @val @scope("Reflect") external get: (dict<'a>, string) => nullable<'a> = "get"
  @val @scope("Object") external fromEntries: array<(string, 'a)> => dict<'a> = "fromEntries"
}

module Json = {
  let sortedStringify: 'a => string = %raw(`
function sortedStringify(value) {
  return JSON.stringify(value, function(_key, value) {
    if (value && typeof value === "object" && !Array.isArray(value)) {
      const sorted = {};
      for (const key of Object.keys(value).sort()) {
        sorted[key] = value[key];
      }
      return sorted;
    }
    return value;
  });
}`)
}

type t<'a, 'query> = {
  get: string => loadable<'a>,
  array: 'query => loadable<array<'a>>,
  dict: 'query => loadable<dict<'a>>,
  upsert: 'a => option<unit => unit>,
  sync: 'a => unit,
  tick: unit => unit,
}

type remote<'a, 'query> = {
  online: bool,
  fetch: ('query, Channel.t<array<'a>, string>) => option<unit => unit>,
  upsert: ('a, Channel.t<'a, upsertIssue<'a>>) => option<unit => unit>,
}

type meta<'query> = {
  filter: 'query,
  mutable fetched: float,
  mutable idle: option<float>,
}

let emitter = (run: 'value => unit) =>
  (self: Channel.t<'a, 'issue>) =>
    (value: 'value) =>
      switch self.state {
      | Live => run(value)
      | Cancelled => ()
      }

let makeChannel = (~emit, ~fail) => {
  open Tilia
  open Channel
  let (state, setState) = Tilia.signal(Live)
  let channel = carve(({derived}) => {
    state: lift(state),
    emit: derived(emitter(emit)),
    fail: derived(emitter(fail)),
  })
  (channel, () => setState(Cancelled))
}

module Fetch = {
  type t<'a, 'query> = {
    replay: unit => unit,
    resolve: ('query, array<'a>) => unit,
  }

  let make = (~replay, ~resolve) => {replay, resolve}
}

module Upsert = {
  type entry<'a> = {
    value: 'a,
    mutable active: bool,
    released: ref<bool>,
    canceler: ref<unit => unit>,
    cleaner: ref<unit => unit>,
    stopper: unit => unit,
  }

  type entries<'a> = Dict.t<entry<'a>>
  type t<'a> = {
    send: 'a => option<unit => unit>,
    replay: unit => unit,
    cancel: unit => unit,
  }

  let make = (~id: 'a => string, ~remote: remote<'a, 'query>, ~resolve: 'a => 'a) => {
    let entries: entries<'a> = Dict.make()

    let stop = entry => {
      entry.stopper()
      entry.active = false
    }

    let remove = (itemId, entry) =>
      switch Dict.get(entries, itemId) {
      | Value(current) if current == entry => {
          stop(current)
          Dict.delete(entries, itemId)
          true
        }
      | _ => false
      }

    let cancel = () =>
      Dict.keys(entries)->Array.forEach(itemId =>
        switch Dict.get(entries, itemId) {
        | Value(entry) if entry.active => stop(entry)
        | _ => ()
        }
      )

    let dispatch = (itemId, entry) => {
      let onEmit = value => {
        if remove(itemId, entry) {
          ignore(resolve(value))
        }
      }
      let onFail = issue => {
        if remove(itemId, entry) {
          switch issue {
          | Conflict(server) => ignore(resolve(server))
          | Rejected(_) => ()
          | Offline => ()
          }
        }
      }
      let (channel, cancelChannel) = makeChannel(~emit=onEmit, ~fail=onFail)
      entry.active = true
      entry.canceler := cancelChannel
      let done = switch remote.upsert(entry.value, channel) {
      | Some(done) => done
      | None => () => ()
      }
      entry.cleaner := done
      if entry.released.contents {
        done()
      }
      switch Dict.get(entries, itemId) {
      | Value(current) if current == entry && current.active => ()
      | _ => entry.stopper()
      }
    }

    let replay = () =>
      if remote.online {
        Dict.keys(entries)->Array.forEach(itemId =>
          switch Dict.get(entries, itemId) {
          | Value(entry) if !entry.active => dispatch(itemId, entry)
          | _ => ()
          }
        )
      }

    let send = value => {
      let next = resolve(value)
      let itemId = id(next)
      switch Dict.get(entries, itemId) {
      | Value(entry) => stop(entry)
      | _ => ()
      }
      let released = ref(false)
      let canceler = ref(() => ())
      let cleaner = ref(() => ())
      let stopper = () =>
        if !released.contents {
          released := true
          canceler.contents()
          cleaner.contents()
        }
      let entry = {
        value: next,
        active: false,
        released,
        canceler,
        cleaner,
        stopper,
      }
      Dict.set(entries, itemId, entry)
      if remote.online {
        replay()
      }
      Some(() => ignore(remove(itemId, entry)))
    }

    {send, replay, cancel}
  }
}

module Sync = {
  type t<'a> = {
    replay: unit => unit,
    resolve: 'a => 'a,
  }

  let make = (~fetch: Fetch.t<'a, 'query>, ~upsert: Upsert.t<'a>, ~resolve: 'a => 'a) => {
    let replay = () => {
      fetch.replay()
      upsert.replay()
    }
    {replay, resolve}
  }
}

let defaultNow = () => Date.now() /. 1000.0

let make = (
  ~id,
  ~remote,
  ~stale=30.0,
  ~gc=300.0,
  ~now=defaultNow,
  ~key=Json.sortedStringify,
  ~invalidates=(_, _) => false,
  (),
) => {
  let cache: Dict.t<'a> = Dict.make()->Tilia.tilia
  let queries: Dict.t<loadable<array<string>>> = Dict.make()->Tilia.tilia
  let meta: Dict.t<meta<'query>> = Dict.make()
  let staleKeys: Dict.t<bool> = Dict.make()->Tilia.tilia
  let fetchCancels: Dict.t<unit => unit> = Dict.make()

  let stopFetch = cacheKey =>
    switch Dict.get(fetchCancels, cacheKey) {
    | Value(cancel) => {
        cancel()
        Dict.delete(fetchCancels, cacheKey)
      }
    | _ => ()
    }

  let invalidate = item =>
    Dict.keys(meta)->Array.forEach(cacheKey =>
      switch Dict.get(meta, cacheKey) {
      | Value(m) if invalidates(m.filter, item) => Dict.set(staleKeys, cacheKey, true)
      | _ => ()
      }
    )

  let resolve = item => {
    Dict.set(cache, id(item), item)
    invalidate(item)
    item
  }

  let startFetch = (cacheKey, filter, set) => {
    stopFetch(cacheKey)
    let onEmit = list => {
      let ids = list->Array.map(item => {
        let itemId = id(item)
        Dict.set(cache, itemId, item)
        itemId
      })
      set(Loaded(ids))
      switch Dict.get(meta, cacheKey) {
      | Value(m) => m.fetched = now()
      | _ => ()
      }
      Dict.delete(staleKeys, cacheKey)
    }
    let onFail = _message => {
      switch Dict.get(meta, cacheKey) {
      | Value(m) => m.fetched = now()
      | _ => ()
      }
      Dict.delete(staleKeys, cacheKey)
    }
    let (channel, cancelChannel) = makeChannel(~emit=onEmit, ~fail=onFail)
    let cleanup = switch remote.fetch(filter, channel) {
    | Some(cleanup) => cleanup
    | None => () => ()
    }
    Dict.set(fetchCancels, cacheKey, () => {
      cancelChannel()
      cleanup()
    })
  }

  let loader = (cacheKey, filter) =>
    (_prev, set) =>
      switch Dict.get(staleKeys, cacheKey) {
      | Undefined => ()
      | _ => startFetch(cacheKey, filter, set)
      }

  let fetch = Fetch.make(
    ~replay=() => {
      let canopy = Tilia._canopy(queries)
      Set.forEach(canopy.live, cacheKey => Dict.set(staleKeys, cacheKey, true))
    },
    ~resolve=(_filter, rows) =>
      rows->Array.forEach(item => {
        Dict.set(cache, id(item), item)
      }),
  )

  let writes = Upsert.make(~id, ~remote, ~resolve)
  let syncer = Sync.make(~fetch, ~upsert=writes, ~resolve)
  let online = ref(remote.online)

  Tilia.watch(
    () => remote.online,
    live => {
      let prev = online.contents
      online := live
      if !prev && live {
        syncer.replay()
      } else if prev && !live {
        writes.cancel()
      }
    },
  )

  let get = id =>
    switch Dict.get(cache, id) {
    | Value(item) => Loaded(item)
    | _ => NotFound
    }

  let query = filter => {
    let cacheKey = key(filter)
    switch Dict.get(queries, cacheKey) {
    | Value(q) => q
    | _ => {
        Dict.set(meta, cacheKey, {filter, fetched: 0.0, idle: None})
        Dict.set(staleKeys, cacheKey, true)
        let s = Tilia.source(Loading, loader(cacheKey, filter))
        Dict.set(queries, cacheKey, s)
        Dict.getKnown(queries, cacheKey)
      }
    }
  }

  let array = filter =>
    switch query(filter) {
    | Loading => Loading
    | NotFound => NotFound
    | Loaded(ids) =>
      Loaded(ids->Array.map(id => Tilia.computed(() => Dict.getKnown(cache, id)))->Tilia.tilia)
    }

  let dict = filter =>
    switch query(filter) {
    | Loading => Loading
    | NotFound => NotFound
    | Loaded(ids) =>
      Loaded(
        ids
        ->Array.map(id => (id, Tilia.computed(() => Dict.getKnown(cache, id))))
        ->Object.fromEntries
        ->Tilia.tilia,
      )
    }

  let sync = item => {
    ignore(syncer.resolve(item))
  }

  let upsert = item => writes.send(item)

  let tick = () => {
    let current = now()
    let canopy = Tilia._canopy(queries)
    Set.forEach(canopy.live, k =>
      switch Dict.get(meta, k) {
      | Value(m) => {
          m.idle = None
          if current -. m.fetched >= stale {
            Dict.set(staleKeys, k, true)
          }
        }
      | _ => ()
      }
    )
    let evicted = ref(false)
    Set.forEach(canopy.idle, k =>
      switch Dict.get(meta, k) {
      | Value(m) =>
        switch m.idle {
        | None => m.idle = Some(current)
        | Some(t) if current -. t >= gc => {
            stopFetch(k)
            Dict.delete(queries, k)
            Dict.delete(meta, k)
            Dict.delete(staleKeys, k)
            evicted := true
          }
        | Some(_) => ()
        }
      | _ => ()
      }
    )
    if evicted.contents {
      let referenced = Set.make()
      Dict.keys(queries)->Array.forEach(k =>
        switch Dict.getKnown(queries, k) {
        | Loaded(ids) => ids->Array.forEach(id => Set.add(referenced, id))
        | _ => ()
        }
      )
      Dict.keys(cache)->Array.forEach(id =>
        if !Set.has(referenced, id) {
          Dict.delete(cache, id)
        }
      )
    }
  }

  {get, array, dict, upsert, sync, tick}
}
