type loadable<'a> =
  | Loading
  | Loaded('a)
  | NotFound

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
  upsert: (string, 'a) => unit,
  sync: 'a => unit,
  tick: unit => unit,
}

type meta<'query> = {
  filter: 'query,
  mutable fetched: float,
  mutable idle: option<float>,
}

type data<'a, 'query> = {
  id: 'a => string,
  fetch: 'query => promise<array<'a>>,
  now: unit => float,
  cache: Dict.t<'a>,
  queries: Dict.t<loadable<array<string>>>,
  meta: Dict.t<meta<'query>>,
  stale: Dict.t<bool>,
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
  let data = {
    id,
    fetch,
    now,
    cache: Dict.make()->Tilia.tilia,
    queries: Dict.make()->Tilia.tilia,
    meta: Dict.make(),
    stale: Dict.make()->Tilia.tilia,
  }

  let invalidate = item =>
    Dict.keys(data.meta)->Array.forEach(cacheKey =>
      switch Dict.get(data.meta, cacheKey) {
      | Value(m) if invalidates(m.filter, item) => Dict.set(data.stale, cacheKey, true)
      | _ => ()
      }
    )

  let sync = item => {
    Dict.set(data.cache, data.id(item), item)
    invalidate(item)
  }

  let upsertItem = (id, item) => {
    Dict.set(data.cache, id, item)
    invalidate(item)
    ignore(upsert(id, item))
  }

  let get = id =>
    switch Dict.get(data.cache, id) {
    | Value(item) => Loaded(item)
    | _ => NotFound
    }

  let loader = (cacheKey, filter) => async (_prev, set) =>
    switch Dict.get(data.stale, cacheKey) {
    | Undefined => ()
    | _ => {
        let list = await data.fetch(filter)
        let ids = list->Array.map(item => {
          let id = data.id(item)
          Dict.set(data.cache, id, item)
          id
        })
        set(Loaded(ids))
        switch Dict.get(data.meta, cacheKey) {
        | Value(m) => m.fetched = data.now()
        | _ => ()
        }
        Dict.delete(data.stale, cacheKey)
      }
    }

  let query = filter => {
    let cacheKey = key(filter)
    switch Dict.get(data.queries, cacheKey) {
    | Value(q) => q
    | _ => {
        Dict.set(data.meta, cacheKey, {filter, fetched: 0.0, idle: None})
        Dict.set(data.stale, cacheKey, true)
        let s = Tilia.source(Loading, loader(cacheKey, filter))
        Dict.set(data.queries, cacheKey, s)
        Dict.getKnown(data.queries, cacheKey)
      }
    }
  }

  let array = filter =>
    switch query(filter) {
    | Loading => Loading
    | NotFound => NotFound
    | Loaded(ids) =>
      Loaded(ids->Array.map(id => Tilia.computed(() => Dict.getKnown(data.cache, id)))->Tilia.tilia)
    }

  let dict = filter =>
    switch query(filter) {
    | Loading => Loading
    | NotFound => NotFound
    | Loaded(ids) =>
      Loaded(
        ids
        ->Array.map(id => (id, Tilia.computed(() => Dict.getKnown(data.cache, id))))
        ->Object.fromEntries
        ->Tilia.tilia,
      )
    }

  let tick = () => {
    let now = data.now()
    let canopy = Tilia._canopy(data.queries)
    Set.forEach(canopy.live, k =>
      switch Dict.get(data.meta, k) {
      | Value(m) => {
          m.idle = None
          if now -. m.fetched >= stale {
            Dict.set(data.stale, k, true)
          }
        }
      | _ => ()
      }
    )
    let evicted = ref(false)
    Set.forEach(canopy.idle, k =>
      switch Dict.get(data.meta, k) {
      | Value(m) =>
        switch m.idle {
        | None => m.idle = Some(now)
        | Some(t) if now -. t >= gc => {
            Dict.delete(data.queries, k)
            Dict.delete(data.meta, k)
            Dict.delete(data.stale, k)
            evicted := true
          }
        | Some(_) => ()
        }
      | _ => ()
      }
    )
    if evicted.contents {
      let referenced = Set.make()
      Dict.keys(data.queries)->Array.forEach(k =>
        switch Dict.getKnown(data.queries, k) {
        | Loaded(ids) => ids->Array.forEach(id => Set.add(referenced, id))
        | _ => ()
        }
      )
      Dict.keys(data.cache)->Array.forEach(id =>
        if !Set.has(referenced, id) {
          Dict.delete(data.cache, id)
        }
      )
    }
  }

  {get, array, dict, upsert: upsertItem, sync, tick}
}
