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

type entryState = Pristine | LoadedLocal | LoadedRemote | LiveRemote

/**
 * Per-query runtime state. The result lives in a signal so reads inside a
 * `Tilia.observe` re-run when a channel delivers fresher results.
 */
type entry<'a, 'query> = {
  key: string,
  query: 'query,
  result_: Tilia.signal<loadable<array<'a>>>,
  mutable lastSeen: float,
  mutable refreshedAt: float,
  set: loadable<array<'a>> => unit,
  mutable state: entryState,
}

let makeFetch = (remote, local, loaded) =>
  entry => {
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
                entry.state = LoadedLocal
                loaded(entry, values, true)
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
            loaded(entry, values, false)
          },
          live: values => {
            entry.state = LiveRemote
            loaded(entry, values, false)
            entry.set(Failed({message: `Local fetch should not call live.`}))
          },
          fail: message => entry.set(Failed({message: message})),
        },
      )
    }
  }

let makeGetEntry = (remote, local, entries, key, loaded, now) => {
  let fetch = makeFetch(remote, local, loaded)
  query => {
    let k = key(query)
    switch entries->Dict.get(k) {
    | Some(entry) => entry
    | None =>
      let (result_, set) = Tilia.signal(Loading)
      let entry = {
        lastSeen: now(),
        refreshedAt: 0.0,
        key: k,
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
}

let makeOne = getEntry =>
  query =>
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
    }

let makeArray = getEntry => query => getEntry(query).result_.value

let makeUpsert = (
  id: 'a => string,
  remote: remote<'a, 'query>,
  local: option<local<'a, 'query>>,
  itemById: dict<'a>,
) =>
  value => {
    // Optimistic write
    itemById->Dict.set(id(value), value)
    // FIXME: we need to manage the outbox, with or without local.
    let write: Channel.write<'a> = {
      set: value => {
        itemById->Dict.set(id(value), value)
      },
      removed: _ => (),
      retry: () => (),
      fail: _ => (),
    }
    // TODO : Update in-memory element by id and queries, mark as dirty in local, update local queries that match.
    switch local {
    | None => ()
    | Some(local) => local.push([Upsert({value: value})])
    }
    remote.push([Upsert({value: value})], write)
  }
let makeTick = (now, expiry, entries) =>
  /*
    Does this list of checks make sense ?
    Every tick : record lastSeen.
    Every expiry.refresh / 8 : check needRefresh.
    Every expiry.memory / 8 : check needRemove.
    Every expiry.local / 8 : check needPurge.
    
    needRefresh = 
      // LiveRemote is not refreshed and all other states are refreshed on transition to online.
      entry.state === LoadedRemote &&
      // Only refresh every expiry.refresh time.
      now > refreshedAt + expiry.refresh &&
      // Only refresh things that have been recently seen.
      now < lastSeen + expiry.refresh,
    // Only remove things that haven't been seen for a long time.
    needRemove = now > lastSeen + expiry.memory,
    // Only purge things that haven't been seen for a very long time.
    // needPurge needs access to the stored queries inside local storage.
    needPurge = now > lastSeen + expiry.local,

    // For every purge mechanism, we need to:
    //  1. remove the queries
    //  2. for all ids in the removed queries (or all ids in the memory resp. local database), check if they are referenced by another query
    //  3. if not, remove the items from the memory resp. local database.
 */
  () => {
    entries->Dict.forEach(entry => {
      switch entry.result_.value {
      | Loaded({data, local}) =>
        if local {
          entry.set(Loaded({data, local: true}))
        }
      | _ => ()
      }
    })
  }

let make = (
  ~id,
  ~matches as _matches,
  ~remote,
  ~local=?,
  ~expiry=_expiry,
  ~now=_now,
  ~key=sortedStringify,
  ~sort=_no_sort,
) => {
  let itemById: dict<'a> = Dict.make()->Tilia.tilia
  let idsByKey: dict<array<string>> = Dict.make()->Tilia.tilia

  // Should be
  // let entries: dict<entry<'query>> = Dict.make()
  let entries: dict<entry<'a, 'query>> = Dict.make()
  let loaded = (entry, values, local) => {
    values->Array.forEach(value => {
      itemById->Dict.set(id(value), value)
    })
    let ids = values->Array.map(id)
    idsByKey->Dict.set(entry.key, ids)
    // We make the entry signal rebuild on changes to ids or any of the id in the list.
    let build = () =>
      idsByKey
      ->Dict.get(entry.key)
      ->Option.getOr([])
      ->Array.filterMap(id => itemById->Dict.get(id))
      ->sort // sorting must be watched so that edits to keys used by sort make the list update.
    entry.set(Loaded({data: Tilia.computed(build), local}))
  }

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

  let getEntry = makeGetEntry(remote, local, entries, key, loaded, now)

  {
    one: makeOne(getEntry),
    array: makeArray(getEntry),
    // TODO: on upsert, should match queries and update the ids + the stored item. If no query
    // matches, create a query by id and mark last seen as now.
    upsert: makeUpsert(id, remote, local, itemById),
    remove: _id => (),
    receive: {changed: _values => (), removed: _ids => ()},
    status: {pending: 0, rejected: []},
    retry: _rejection => (),
    discard: _rejection => (),
    tick: makeTick(now, expiry, entries),
    dispose: clearOnline,
    _canopy: () => {live: entries->Dict.keysToArray, idle: []},
  }
}
