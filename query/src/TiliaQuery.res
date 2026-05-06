type loadable<'a> =
  | Loading
  | Loaded('a)
  | NotFound

module Dict = {
  type t<'a>
  @new external make: unit => t<'a> = "Map"
  @send external get: (t<'a>, string) => nullable<'a> = "get"
  @send external set: (t<'a>, string, 'a) => unit = "set"
}

type t<'a> = {
  get: string => loadable<'a>,
  find: string => loadable<array<string>>,
}

type data<'a> = {
  id: 'a => string,
  fetch: string => promise<array<'a>>,
  objects: Dict.t<'a>,
  queries: Dict.t<Tilia.signal<loadable<array<string>>>>,
}

let run = async (data, key, set) => {
  let list = await data.fetch(key)
  let ids = list->Array.map(item => {
    let id = data.id(item)
    Dict.set(data.objects, id, item)
    id
  })
  set(Loaded(ids))
}

let make = (~id, ~fetch, ()) => {
  let data = {
    id,
    fetch,
    objects: Dict.make(),
    queries: Dict.make(),
  }

  let get = id =>
    switch Dict.get(data.objects, id) {
    | Value(item) => Loaded(item)
    | _ => NotFound
    }

  let find = key => {
    let query = switch Dict.get(data.queries, key) {
    | Value(query) => query
    | _ => {
        let (query, set) = Tilia.signal(Loading)
        Dict.set(data.queries, key, query)
        ignore(run(data, key, set))
        query
      }
    }
    query.value
  }

  {get, find}
}

let toArray = repo =>
  list =>
    switch list {
    | Loading => Loading
    | NotFound => NotFound
    | Loaded(ids) => {
        let loaded = ids->Array.reduce([], (acc, id) =>
          switch repo.get(id) {
          | Loaded(item) => [...acc, item]
          | _ => acc
          }
        )
        Loaded(loaded)
      }
    }


/*


let byId => repo => list => switch list.value {
  | Loading => Loading
  | NotFound => NotFound
  | Loaded(ids) => Object.fromValues(list->Array.map(id => (id, lift(repo.getUnsafe(id))))
}

// if in the code we use
data = list->byId(repo)
bob = data['xxx'] this is reactive and focused on repo.getUnsafe read. So any changes to the object id can be pushed by updating the tilia cache in repo.getUnsafe.

 */