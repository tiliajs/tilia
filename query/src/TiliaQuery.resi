@tag("state")
type loadable<'a> =
  | @as("loading") Loading
  | @as("loaded") Loaded({data: 'a})
  | @as("notFound") NotFound

module Channel: {
  type state =
    | @as("live") Live
    | @as("cancelled") Cancelled

  // Read path (local and remote fetch).
  type fetch<'a> = {
    state: state,
    emit: array<'a> => unit,
    fail: string => unit,
    covered: unit => unit,
  }

  // Write path (remote upsert).
  type write<'a> = {
    state: state,
    emit: 'a => unit,
    offline: unit => unit,
    conflict: 'a => unit,
    reject: string => unit,
  }
}

// An unsynced operation: a put, or a delete when `deleted` is true.
type write<'a> = {
  value: 'a,
  deleted: bool,
}

// A write permanently refused by the remote.
type rejection<'a> = {
  value: 'a,
  deleted: bool,
  message: string,
}

type fetchError = {
  key: string,
  message: string,
}

// Reactive sync state for UI: pending outbox size, refused writes, last
// remote fetch failure.
type status<'a> = {
  mutable pending: int,
  mutable rejected: array<rejection<'a>>,
  mutable error: option<fetchError>,
}

type remote<'a, 'query> = {
  online: bool,
  fetch: ('query, Channel.fetch<'a>) => option<unit => unit>,
  upsert: ('a, Channel.write<'a>) => unit,
  remove: ('a, Channel.write<'a>) => unit,
}

type store<'a, 'query> = {
  fetch: ('query, Channel.fetch<'a>) => option<unit => unit>,
  save: ('a, bool) => unit,
  remove: ('a, bool) => unit,
  dirty: unit => promise<array<write<'a>>>,
}

type config<'a, 'query> = {
  id: 'a => string,
  remote: remote<'a, 'query>,
  local?: store<'a, 'query>,
  stale?: float,
  gc?: float,
  now?: unit => float,
  key?: 'query => string,
  invalidates?: ('query, 'a) => bool,
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
  one: 'query => loadable<'a>,
  array: 'query => loadable<array<'a>>,
  dict: 'query => loadable<dict<'a>>,
  upsert: 'a => unit,
  remove: 'a => unit,
  sync: 'a => unit,
  tick: unit => unit,
  status: status<'a>,
  dismiss: unit => unit,
  dispose: unit => unit,
  clear: unit => unit,
}

let make: config<'a, 'query> => t<'a, 'query>
