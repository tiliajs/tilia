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
}

type data<'a, 'query> = {
  id: 'a => string,
  fetch: 'query => promise<array<'a>>,
  cache: Dict.t<'a>,
  queries: Dict.t<loadable<array<string>>>,
}

let run = async (data, cacheKey, filter) => {
  let list = await data.fetch(filter)
  let ids = list->Array.map(item => {
    let id = data.id(item)
    Dict.set(data.cache, id, item)
    id
  })
  Dict.set(data.queries, cacheKey, Loaded(ids))
}

let make = (~id, ~fetch, ~upsert, ~key=Json.sortedStringify, ()) => {
  open Tilia
  let data = {
    id,
    fetch,
    cache: Dict.make()->tilia,
    queries: Dict.make()->tilia,
  }

  let upsertItem = (id, item) => {
    Dict.set(data.cache, id, item)
    ignore(upsert(id, item))
  }

  let get = id =>
    switch Dict.get(data.cache, id) {
    | Value(item) => Loaded(item)
    | _ => NotFound
    }

  let query = filter => {
    let cacheKey = key(filter)
    switch Dict.get(data.queries, cacheKey) {
    | Value(query) => query
    | _ => {
        Dict.set(data.queries, cacheKey, Loading)
        ignore(run(data, cacheKey, filter))
        Loading
      }
    }
  }

  let array = filter =>
    switch query(filter) {
    | Loading => Loading
    | NotFound => NotFound
    | Loaded(ids) => Loaded(ids->Array.map(id => computed(() => Dict.getKnown(data.cache, id)))->tilia)
    }

  let dict = filter =>
    switch query(filter) {
    | Loading => Loading
    | NotFound => NotFound
    | Loaded(ids) =>
      Loaded(
        ids
        ->Array.map(id => (id, computed(() => Dict.getKnown(data.cache, id))))
        ->Object.fromEntries
        ->Tilia.tilia,
      )
    }

  {get, array, dict, upsert: upsertItem}
}
