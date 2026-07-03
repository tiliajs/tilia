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
  upsert: 'a => unit,
  sync: 'a => unit,
  tick: unit => unit,
}

type remote<'a, 'query> = {
  online: bool,
  fetch: ('query, Channel.t<array<'a>, string>) => option<unit => unit>,
  upsert: ('a, Channel.t<'a, upsertIssue<'a>>) => unit,
}

type store<'a, 'query> = {
  fetch: ('query, Channel.t<array<'a>, string>) => option<unit => unit>,
  save: ('a, bool) => unit,
  dirty: unit => promise<array<'a>>,
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

module Upsert = {
  type entry<'a> = {
    value: 'a,
    // None = queued, Some(f) = in flight, f cancels the channel
    mutable cancel: option<unit => unit>,
  }

  type entries<'a> = Dict.t<entry<'a>>
  type t<'a> = {
    send: 'a => unit,
    replay: unit => unit,
    cancel: unit => unit,
    pending: string => bool,
  }

  let make = (
    ~id: 'a => string,
    ~remote: remote<'a, 'query>,
    ~local: store<'a, 'query>,
    ~resolve: 'a => 'a,
  ) => {
    let entries: entries<'a> = Dict.make()

    let pending = itemId =>
      switch Dict.get(entries, itemId) {
      | Value(_) => true
      | _ => false
      }

    let stop = (entry: entry<'a>) =>
      switch entry.cancel {
      | Some(cancel) => {
          cancel()
          entry.cancel = None
        }
      | None => ()
      }

    let remove = (itemId, entry) =>
      switch Dict.get(entries, itemId) {
      | Value(current) if current === entry => {
          stop(current)
          Dict.delete(entries, itemId)
          true
        }
      | _ => false
      }

    let cancel = () =>
      Dict.keys(entries)->Array.forEach(itemId =>
        switch Dict.get(entries, itemId) {
        | Value(entry) => stop(entry)
        | _ => ()
        }
      )

    let dispatch = (itemId, entry: entry<'a>) => {
      let settle = value => {
        if remove(itemId, entry) {
          local.save(value, false)
          ignore(resolve(value))
        }
      }
      let onFail = issue =>
        switch issue {
        | Offline =>
          // Keep the entry queued and dirty for the next reconnect.
          switch Dict.get(entries, itemId) {
          | Value(current) if current === entry => stop(current)
          | _ => ()
          }
        | Conflict(server) => settle(server)
        | Rejected(_) =>
          if remove(itemId, entry) {
            // Stop retries; a later fetch restores server truth.
            local.save(entry.value, false)
          }
        }
      let (channel, cancelChannel) = makeChannel(~emit=settle, ~fail=onFail)
      entry.cancel = Some(cancelChannel)
      remote.upsert(entry.value, channel)
    }

    let replay = () =>
      if remote.online {
        Dict.keys(entries)->Array.forEach(itemId =>
          switch Dict.get(entries, itemId) {
          | Value(entry) =>
            switch entry.cancel {
            | None => dispatch(itemId, entry)
            | Some(_) => ()
            }
          | _ => ()
          }
        )
      }

    let send = value => {
      let itemId = id(value)
      switch Dict.get(entries, itemId) {
      | Value(entry) => stop(entry)
      | _ => ()
      }
      Dict.set(entries, itemId, {value, cancel: None})
      local.save(value, true)
      ignore(resolve(value))
      if remote.online {
        replay()
      }
    }

    {send, replay, cancel, pending}
  }
}

let defaultNow = () => Date.now() /. 1000.0

let make = (
  ~id,
  ~remote,
  ~local=?,
  ~stale=30.0,
  ~gc=300.0,
  ~now=defaultNow,
  ~key=Json.sortedStringify,
  ~invalidates=(_, _) => false,
  (),
) => {
  let local: store<_, _> = switch local {
  | Some(local) => local
  | None => {
      fetch: (_, _) => None,
      save: (_, _) => (),
      dirty: () => Promise.resolve([]),
    }
  }
  let cache: Dict.t<'a> = Dict.make()->Tilia.tilia
  let queries: Dict.t<loadable<array<string>>> = Dict.make()->Tilia.tilia
  let arrays: Dict.t<loadable<array<'a>>> = Dict.make()->Tilia.tilia
  let dicts: Dict.t<loadable<dict<'a>>> = Dict.make()->Tilia.tilia
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

  let writes = Upsert.make(~id, ~remote, ~local, ~resolve)

  let startFetch = (cacheKey, filter, set) => {
    stopFetch(cacheKey)
    let fresh = () =>
      switch Dict.get(meta, cacheKey) {
      | Value(m) => m.fetched = now()
      | _ => ()
      }
    // Remote rows are authoritative: they refresh freshness and write through
    // to the local store. Rows with a pending upsert keep their optimistic value.
    let receive = (authority, list) => {
      let ids = list->Array.map(item => {
        let itemId = id(item)
        if !writes.pending(itemId) {
          Dict.set(cache, itemId, item)
          if authority {
            local.save(item, false)
          }
        }
        itemId
      })
      set(Loaded(ids))
      if authority {
        fresh()
      }
    }
    let tier = (fetch, authority, fail) => {
      let (channel, cancelChannel) = makeChannel(~emit=rows => receive(authority, rows), ~fail)
      let cleanup = switch fetch(filter, channel) {
      | Some(cleanup) => cleanup
      | None => () => ()
      }
      () => {
        cancelChannel()
        cleanup()
      }
    }
    let cancelLocal = tier(local.fetch, false, _ => ())
    let cancelRemote = remote.online ? tier(remote.fetch, true, _ => fresh()) : (() => ())
    Dict.set(fetchCancels, cacheKey, () => {
      cancelLocal()
      cancelRemote()
    })
    Dict.delete(staleKeys, cacheKey)
  }

  let loader = (cacheKey, filter) =>
    (_prev, set) =>
      switch Dict.get(staleKeys, cacheKey) {
      | Undefined => ()
      | _ => startFetch(cacheKey, filter, set)
      }

  let replay = () => {
    let canopy = Tilia._canopy(queries)
    Set.forEach(canopy.live, cacheKey => Dict.set(staleKeys, cacheKey, true))
    writes.replay()
  }

  let online = ref(remote.online)

  Tilia.watch(
    () => remote.online,
    live => {
      let prev = online.contents
      online := live
      if !prev && live {
        replay()
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

  // Views are memoized per query key so repeated reads return the same proxy;
  // the computed rebuilds only when the query's id list changes.
  let array = filter => {
    let cacheKey = key(filter)
    ignore(query(filter))
    switch Dict.get(arrays, cacheKey) {
    | Value(view) => view
    | _ => {
        Dict.set(
          arrays,
          cacheKey,
          Tilia.computed(() =>
            switch Dict.getKnown(queries, cacheKey) {
            | Loading => Loading
            | NotFound => NotFound
            | Loaded(ids) =>
              Loaded(
                ids->Array.map(id => Tilia.computed(() => Dict.getKnown(cache, id)))->Tilia.tilia,
              )
            }
          ),
        )
        Dict.getKnown(arrays, cacheKey)
      }
    }
  }

  let dict = filter => {
    let cacheKey = key(filter)
    ignore(query(filter))
    switch Dict.get(dicts, cacheKey) {
    | Value(view) => view
    | _ => {
        Dict.set(
          dicts,
          cacheKey,
          Tilia.computed(() =>
            switch Dict.getKnown(queries, cacheKey) {
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
          ),
        )
        Dict.getKnown(dicts, cacheKey)
      }
    }
  }

  let sync = item => ignore(resolve(item))

  let upsert = item => writes.send(item)

  let tick = () => {
    let current = now()
    let canopy = Tilia._canopy(queries)
    Set.forEach(canopy.live, k =>
      switch Dict.get(meta, k) {
      | Value(m) => {
          m.idle = None
          if remote.online && current -. m.fetched >= stale {
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
            Dict.delete(arrays, k)
            Dict.delete(dicts, k)
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

  // Boot: queue pending writes from the previous session; replay happens
  // through the normal online flow.
  local.dirty()
  ->Promise.thenResolve(rows => rows->Array.forEach(writes.send))
  ->ignore

  {get, array, dict, upsert, sync, tick}
}
