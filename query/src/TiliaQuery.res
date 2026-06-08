type loadable<'a> =
  | Loading
  | Loaded('a)
  | NotFound

type channelState =
  | Live
  | Cancelled

type channel<'a> = {
  state: unit => channelState,
  emit: 'a => unit,
  error: exn => unit,
}

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

type meta<'query> = {
  filter: 'query,
  mutable fetched: float,
  mutable idle: option<float>,
}

let defaultNow = () => Date.now() /. 1000.0

let make = (
  ~id,
  ~fetch,
  ~upsert,
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
  let remoteUpsert = upsert

  let makeChannel = (~emit, ~error) => {
    let state = ref(Live)
    let cancel = () =>
      switch state.contents {
      | Live => state := Cancelled
      | Cancelled => ()
      }
    let channel = {
      state: () => state.contents,
      emit: value =>
        switch state.contents {
        | Live => emit(value)
        | Cancelled => ()
        },
      error: e =>
        switch state.contents {
        | Live => error(e)
        | Cancelled => ()
        },
    }
    (channel, cancel)
  }

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

  let sync = item => {
    Dict.set(cache, id(item), item)
    invalidate(item)
  }

  let upsert = item => {
    let itemId = id(item)
    Dict.set(cache, itemId, item)
    let (channel, _cancelChannel) = makeChannel(~emit=_ => (), ~error=_ => ())
    let cleanup = remoteUpsert(item, channel)
    invalidate(item)
    cleanup
  }

  let get = id =>
    switch Dict.get(cache, id) {
    | Value(item) => Loaded(item)
    | _ => NotFound
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
    let onError = _e => {
      switch Dict.get(meta, cacheKey) {
      | Value(m) => m.fetched = now()
      | _ => ()
      }
      Dict.delete(staleKeys, cacheKey)
    }
    let (channel, cancelChannel) = makeChannel(~emit=onEmit, ~error=onError)
    let cleanup = switch fetch(filter, channel) {
    | Some(cleanup) => cleanup
    | None => () => ()
    }
    Dict.set(fetchCancels, cacheKey, () => {
      cancelChannel()
      cleanup()
    })
  }

  let loader = (cacheKey, filter) => (_prev, set) =>
    switch Dict.get(staleKeys, cacheKey) {
    | Undefined => ()
    | _ => startFetch(cacheKey, filter, set)
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
    | Loaded(ids) => Loaded(ids->Array.map(id => Tilia.computed(() => Dict.getKnown(cache, id)))->Tilia.tilia)
    }

  let dict = filter =>
    switch query(filter) {
    | Loading => Loading
    | NotFound => NotFound
    | Loaded(ids) =>
      Loaded(ids->Array.map(id => (id, Tilia.computed(() => Dict.getKnown(cache, id))))->Object.fromEntries->Tilia.tilia)
    }

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
