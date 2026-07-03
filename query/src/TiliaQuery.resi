type loadable<'a> =
  | Loading
  | Loaded('a)
  | NotFound

module Channel: {
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
  upsert: 'a => unit,
  sync: 'a => unit,
  tick: unit => unit,
}

let make: (
  ~id: 'a => string,
  ~remote: remote<'a, 'query>,
  ~local: store<'a, 'query>=?,
  ~stale: float=?,
  ~gc: float=?,
  ~now: unit => float=?,
  ~key: 'query => string=?,
  ~invalidates: ('query, 'a) => bool=?,
  unit,
) => t<'a, 'query>
