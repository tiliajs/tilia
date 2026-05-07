type loadable<'a> =
  | Loading
  | Loaded('a)
  | NotFound

type dict<'a>

module Object: {
  @val @scope("Reflect") external get: (dict<'a>, string) => nullable<'a> = "get"
  @val @scope("Object") external fromEntries: array<(string, 'a)> => dict<'a> = "fromEntries"
}

module Json: {
  let sortedStringify: 'a => string
}

type t<'a, 'query> = {
  get: string => loadable<'a>,
  array: 'query => loadable<array<'a>>,
  dict: 'query => loadable<dict<'a>>,
  upsert: (string, 'a) => unit,
  tick: unit => unit,
}

let make: (
  ~id: 'a => string,
  ~fetch: 'query => promise<array<'a>>,
  ~upsert: (string, 'a) => promise<unit>,
  ~stale: float=?,
  ~gc: float=?,
  ~now: unit => float=?,
  ~key: 'query => string=?,
  ~invalidate: ('query, 'a) => bool=?,
  unit,
) => t<'a, 'query>
