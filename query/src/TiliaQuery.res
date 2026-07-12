// TYPES

@tag("state")
type loadable<'a> =
  | @as("loading") Loading
  | @as("loaded") Loaded({data: 'a, local: bool})
  | @as("notFound") NotFound
  | @as("notLocal") NotLocal
  | @as("failed") Failed({message: string})

@tag("op")
type op<'a> =
  | @as("upsert") Upsert({value: 'a})
  | @as("remove") Remove({id: string})

type rejection<'a> = {
  /** The op's value id — the key `retry` / `discard` match on. */
  id: string,
  op: op<'a>,
  message: string,
}
module Channel = {
  type read<'a> = {
    set: array<'a> => unit,
    live: array<'a> => unit,
    fail: string => unit,
  }

  type local<'a> = {
    set: array<'a> => unit,
    unknown: unit => unit,
  }

  type write<'a> = {
    set: 'a => unit,
    removed: string => unit,
    retry: unit => unit,
    fail: string => unit,
  }
}

type expiry = {
  refresh?: float,
  memory?: float,
  local?: float,
}

type status<'a> = {
  pending: int,
  rejected: array<rejection<'a>>,
}

type remote<'a, 'query> = {
  online: Tilia.signal<bool>,
  fetch: ('query, Channel.read<'a>) => unit,
  push: (array<op<'a>>, Channel.write<'a>) => unit,
}

type local<'a, 'query> = {
  fetch: ('query, Channel.local<'a>) => unit,
  push: array<op<'a>> => unit,
  set: (~tag: string, ~key: string, option<string>) => unit,
  get: (~tag: string, ~key: string=?, ~set: array<string> => unit) => unit,
}

type receive<'a> = {
  changed: array<'a> => unit,
  removed: array<string> => unit,
}

type canopy = {
  live: array<string>,
  idle: array<string>,
}

type t<'a, 'query> = {
  one: 'query => loadable<'a>,
  array: 'query => loadable<array<'a>>,
  upsert: 'a => unit,
  remove: string => unit,
  receive: receive<'a>,
  status: status<'a>,
  retry: rejection<'a> => unit,
  discard: rejection<'a> => unit,
  tick: unit => unit,
  dispose: unit => unit,
  _canopy: unit => canopy,
}

// --------------- IMPLEMENTATION

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

let _expiry = {
  // 30 seconds
  refresh: 30_000.0,
  // 5 minutes
  memory: 300_000.0,
  // 30 days
  local: 2_592_000_000.0,
}

let _now = () => Date.now()
let _no_sort = array => array

type entryState = Pristine | LoadedRemote | LiveRemote

/**
 * Per-query runtime state. The result lives in a signal so reads inside a
 * `Tilia.observe` re-run when a channel delivers fresher results.
 */
type entry<'a, 'query> = {
  query: 'query,
  result_: Tilia.signal<loadable<array<'a>>>,
  set: loadable<array<'a>> => unit,
  mutable state: entryState,
}

let make = (
  ~id as _id,
  ~matches as _matches,
  ~remote,
  ~local=?,
  ~expiry as _expiry=_expiry,
  ~now as _now=_now,
  ~key=sortedStringify,
  ~sort=_no_sort,
) => {
  let entries: dict<entry<'a, 'query>> = Dict.make()
  let loaded = (values, local) => Loaded({data: sort(values), local})

  let clearOnline = Tilia.watch(
    () => remote.online.value,
    online => {
      if !online {
        entries->Dict.forEach(entry => {
          switch entry.result_.value {
          | Loading => entry.set(NotLocal)
          | _ => ()
          }
        })
      }
    },
  )

  let fetch = entry => {
    if entry.state !== LiveRemote {
      let unknown = () => {
        if !remote.online.value && entry.state == Pristine {
          // No local storage and no network: nothing can ever answer this query.
          entry.set(NotLocal)
        }
      }

      switch local {
      | None => unknown()
      | Some(local) =>
        local.fetch(
          entry.query,
          {
            set: values => {
              if entry.state == Pristine {
                entry.set(loaded(values, true))
              }
            },
            unknown: () => unknown(),
          },
        )
      }

      remote.fetch(
        entry.query,
        {
          set: values => {
            entry.state = LoadedRemote
            entry.set(loaded(values, false))
          },
          live: values => {
            entry.state = LiveRemote
            entry.set(loaded(values, false))
            entry.set(Failed({message: `Local fetch should not call live.`}))
          },
          fail: message => entry.set(Failed({message: message})),
        },
      )
    }
  }

  let getEntry = query => {
    let k = key(query)
    switch entries->Dict.get(k) {
    | Some(entry) => entry
    | None =>
      let (result_, set) = Tilia.signal(Loading)
      let entry = {
        result_,
        set,
        state: Pristine,
        query,
      }
      entries->Dict.set(k, entry)
      fetch(entry)
      entry
    }
  }

  {
    one: query =>
      switch getEntry(query).result_.value {
      | Loaded({data, local}) =>
        switch data->Array.get(0) {
        | Some(value) => Loaded({data: value, local})
        | None => NotFound
        }
      | Loading => Loading
      | NotFound => NotFound
      | NotLocal => NotLocal
      | Failed({message}) => Failed({message: message})
      },
    array: query => getEntry(query).result_.value,
    upsert: _value => (),
    remove: _id => (),
    receive: {changed: _values => (), removed: _ids => ()},
    status: {pending: 0, rejected: []},
    retry: _rejection => (),
    discard: _rejection => (),
    tick: () => (),
    dispose: clearOnline,
    _canopy: () => {live: entries->Dict.keysToArray, idle: []},
  }
}
