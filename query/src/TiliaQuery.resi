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
  upsert: 'a => option<unit => unit>,
  sync: 'a => unit,
  tick: unit => unit,
}

let make: (
  ~id: 'a => string,
  ~fetch: ('query, channel<array<'a>>) => option<unit => unit>,
  ~upsert: ('a, channel<unit>) => option<unit => unit>,
  ~stale: float=?,
  ~gc: float=?,
  ~now: unit => float=?,
  ~key: 'query => string=?,
  ~invalidates: ('query, 'a) => bool=?,
  unit,
) => t<'a, 'query>
