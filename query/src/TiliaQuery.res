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
  refresh: float,
  memory: float,
  local: float,
}

type status<'a> = {
  mutable pending: int,
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
  ids: (~set: array<string> => unit) => unit,
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
  /** Testing hook: ids held by an in-memory query. */
  _ids: 'query => option<array<string>>,
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

/** Runtime state for one in-memory query. */
type entry<'query> = {
  key: string,
  query: 'query,
  mutable lastSeen: float,
  mutable refreshedAt: float,
  /** Latest remote fetch attempt, used to throttle refreshes. */
  mutable fetchedAt: float,
  mutable state: entryState,
}

/** Durable query result used to find rows still reachable during local purge. */
type queryRecord<'query> = {
  key: string,
  // The query itself, so matches can run on disk-only records. None on synthetics.
  query: option<'query>,
  mutable ids: array<string>,
  mutable lastSeen: float,
}

@scope("JSON") @val external encodeRecord: queryRecord<'query> => string = "stringify"

/** Returns None on malformed kv data: the entry is skipped, not fatal. */
let parseRecord: string => option<queryRecord<'query>> = %raw(`
function parseRecord(value) {
  try {
    const r = JSON.parse(value);
    if (r && typeof r.key === "string" && Array.isArray(r.ids) && typeof r.lastSeen === "number") {
      return r;
    }
  } catch (_) {}
  return undefined;
}`)

/** A queued write, ordered by `seq` and guarded from duplicate pushes by `flight`. */
type outboxOp<'a> = {
  seq: float,
  op: op<'a>,
  mutable flight: bool,
}

/** The persisted form drops the transient `flight` flag. */
let encodeOp: outboxOp<'a> => string = %raw(`
function encodeOp(entry) {
  return JSON.stringify({seq: entry.seq, op: entry.op});
}`)

/** Returns None on malformed kv data: the entry is skipped, not fatal. */
let parseOp: string => option<outboxOp<'a>> = %raw(`
function parseOp(value) {
  try {
    const r = JSON.parse(value);
    if (r && typeof r.seq === "number" && r.op && (r.op.op === "upsert" || r.op.op === "remove")) {
      return {seq: r.seq, op: r.op, flight: false};
    }
  } catch (_) {}
  return undefined;
}`)

/** Keys of the queries whose result is currently observed ("open"). */
let observedKeys = results => Tilia._canopy(results).live

/** Missing key means the entry was never created: treat as still loading. */
let getResult = (results, entry: entry<'query>) =>
  results->Dict.get(entry.key)->Option.getOr(Loading)

let makeFetch = (remote, local, loaded, results, now) =>
  entry => {
    if entry.state !== LiveRemote {
      let unknown = () => {
        if !remote.online.value && entry.state == Pristine {
          // No local storage and no network: nothing can ever answer this query.
          results->Dict.set(entry.key, NotLocal)
        }
      }

      if entry.state == Pristine {
        // Local only materializes a query: a refresh would discard its answer.
        switch local {
        | None => unknown()
        | Some(local) =>
          local.fetch(
            entry.query,
            {
              set: values => {
                if entry.state == Pristine {
                  entry.state = LoadedLocal
                  loaded(entry, values, false)
                }
              },
              unknown: () => unknown(),
            },
          )
        }
      }

      entry.fetchedAt = now()
      remote.fetch(
        entry.query,
        {
          set: values => {
            entry.state = LoadedRemote
            loaded(entry, values, true)
          },
          live: values => {
            entry.state = LiveRemote
            loaded(entry, values, true)
          },
          fail: message => results->Dict.set(entry.key, Failed({message: message})),
        },
      )
    }
  }

let makeGetEntry = (fetch, entries, results, key, now) =>
  query => {
    let k = key(query)
    switch entries->Dict.get(k) {
    | Some(entry) => entry
    | None =>
      let entry = {
        lastSeen: now(),
        refreshedAt: 0.0,
        fetchedAt: 0.0,
        key: k,
        state: Pristine,
        query,
      }
      results->Dict.set(k, Loading)
      entries->Dict.set(k, entry)
      fetch(entry)
      entry
    }
  }

let makeOne = (getEntry, results) =>
  query =>
    switch getResult(results, getEntry(query)) {
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

let makeArray = (getEntry, results) => query => getResult(results, getEntry(query))

let make = (
  ~id,
  ~matches,
  ~remote,
  ~local=?,
  ~expiry=_expiry,
  ~now=_now,
  ~key=sortedStringify,
  ~sort=_no_sort,
) => {
  let itemById: dict<'a> = Dict.make()->Tilia.tilia
  let idsByKey: dict<array<string>> = Dict.make()->Tilia.tilia

  let entries: dict<entry<'query>> = Dict.make()
  let results: dict<loadable<array<'a>>> = Dict.make()->Tilia.tilia

  // The write-through registry wins over older persisted records during purge.
  let queryTag = "query"
  let syntheticPrefix = "__id:"
  let registry: dict<queryRecord<'query>> = Dict.make()
  let persistRecord = record =>
    switch local {
    | None => ()
    | Some(local) => local.set(~tag=queryTag, ~key=record.key, Some(encodeRecord(record)))
    }
  // A late delivery must not extend the retention of an unobserved query.
  let recordSeen = (entry: entry<'query>, ids) =>
    switch local {
    | None => ()
    | Some(_) =>
      let record = switch registry->Dict.get(entry.key) {
      | Some(record) => record
      | None =>
        let record = {key: entry.key, query: Some(entry.query), ids: [], lastSeen: 0.0}
        registry->Dict.set(entry.key, record)
        record
      }
      record.lastSeen = Math.max(record.lastSeen, entry.lastSeen)
      record.ids = ids
      persistRecord(record)
    }

  // Track queued writes in order and persist them for restart recovery.
  let status: status<'a> = Tilia.tilia({pending: 0, rejected: []})
  let outboxTag = "outbox"
  let outbox: array<outboxOp<'a>> = []
  let nextSeq = ref(0.0)
  let syncPending = () => status.pending = outbox->Array.length

  let opId = (op: op<'a>) =>
    switch op {
    | Upsert({value}) => id(value)
    | Remove({id}) => id
    }

  // Keep rejected ops available for optimistic overlay and planned recovery.
  let rejectedOps: dict<outboxOp<'a>> = Dict.make()
  let reject = (entry: outboxOp<'a>, message) => {
    let i = outbox->Array.indexOf(entry)
    if i >= 0 {
      outbox->Array.splice(~start=i, ~remove=1, ~insert=[])
    }
    let rid = opId(entry.op)
    rejectedOps->Dict.set(rid, entry)
    let rejection = {id: rid, op: entry.op, message}
    switch status.rejected->Array.findIndex(r => r.id === rid) {
    | -1 => status.rejected->Array.push(rejection)
    | i => status.rejected->Array.splice(~start=i, ~remove=1, ~insert=[rejection])
    }
    syncPending()
  }

  // Preserve optimistic state when applying remote results.
  let applyPending = (entry: entry<'query>, values) => {
    let apply = (values, op) =>
      switch op {
      | Upsert({value}) =>
        let vid = id(value)
        if !matches(entry.query, value) {
          // A pending move keeps the row out of queries it left.
          values->Array.filter(v => id(v) !== vid)
        } else if values->Array.some(v => id(v) === vid) {
          values->Array.map(v => id(v) === vid ? value : v)
        } else {
          values->Array.concat([value])
        }
      | Remove({id: rid}) => values->Array.filter(v => id(v) !== rid)
      }
    let values =
      rejectedOps->Dict.valuesToArray->Array.reduce(values, (values, {op}) => apply(values, op))
    outbox->Array.reduce(values, (values, {op}) => apply(values, op))
  }

  let loaded = (entry, values, remote) => {
    let values = remote ? applyPending(entry, values) : values
    if remote {
      entry.refreshedAt = now()
      switch local {
      | Some(local) => local.push(values->Array.map(value => Upsert({value: value})))
      | None => ()
      }
    }
    values->Array.forEach(value => {
      itemById->Dict.set(id(value), value)
    })
    let ids = values->Array.map(id)
    recordSeen(entry, ids)
    idsByKey->Dict.set(entry.key, ids)
    // Rebuild when the id list or any listed item changes.
    let build = () =>
      idsByKey
      ->Dict.get(entry.key)
      ->Option.getOr([])
      ->Array.filterMap(id => itemById->Dict.get(id))
      ->sort // Observe sorting so edits to sort keys update the list.
    results->Dict.set(entry.key, Loaded({data: Tilia.computed(build), local: !remote}))
  }

  let confirmed = (entry: outboxOp<'a>) => {
    let i = outbox->Array.indexOf(entry)
    if i >= 0 {
      outbox->Array.splice(~start=i, ~remove=1, ~insert=[])
    }
    switch local {
    | Some(local) => local.set(~tag=outboxTag, ~key=Float.toString(entry.seq), None)
    | None => ()
    }
    syncPending()
  }

  // One push carries every pending op not already in flight, in order.
  let pushPending = () =>
    if remote.online.value {
      let batch = outbox->Array.filter(entry => !entry.flight)
      if batch->Array.length > 0 {
        batch->Array.forEach(entry => entry.flight = true)
        remote.push(
          batch->Array.map(entry => entry.op),
          {
            set: value => {
              let vid = id(value)
              let match = outbox->Array.find(entry =>
                entry.flight &&
                switch entry.op {
                | Upsert({value}) => id(value) === vid
                | Remove(_) => false
                }
              )
              switch match {
              | Some(entry) =>
                // A server-corrected confirmation replaces local copies.
                itemById->Dict.set(vid, value)
                switch local {
                | Some(local) => local.push([Upsert({value: value})])
                | None => ()
                }
                confirmed(entry)
              | None => ()
              }
            },
            removed: rid => {
              let match = outbox->Array.find(entry =>
                entry.flight &&
                switch entry.op {
                | Remove({id}) => id === rid
                | Upsert(_) => false
                }
              )
              switch match {
              | Some(entry) => confirmed(entry)
              | None => ()
              }
            },
            retry: () => batch->Array.forEach(entry => entry.flight = false),
            // Reject only unconfirmed operations still in the outbox.
            fail: message =>
              batch->Array.forEach(entry =>
                if outbox->Array.includes(entry) {
                  reject(entry, message)
                }
              ),
          },
        )
      }
    }

  let enqueue = (op: op<'a>) => {
    let seq = Math.max(now(), nextSeq.contents)
    nextSeq := seq +. 1.0
    let entry = {seq, op, flight: false}
    outbox->Array.push(entry)
    switch local {
    | Some(local) => local.set(~tag=outboxTag, ~key=Float.toString(seq), Some(encodeOp(entry)))
    | None => ()
    }
    syncPending()
    pushPending()
  }

  // Claim a rejection by id, raising when absent.
  let takeRejected = rid => {
    let entry = rejectedOps->Dict.get(rid)->Option.getOrThrow(~message=`no rejection for "${rid}"`)
    rejectedOps->Dict.delete(rid)
    switch status.rejected->Array.findIndex(r => r.id === rid) {
    | -1 => ()
    | i => status.rejected->Array.splice(~start=i, ~remove=1, ~insert=[])
    }
    entry
  }

  // Reuse the original seq and persisted entry so later edits still win.
  let retry = (rejection: rejection<'a>) => {
    let entry = takeRejected(rejection.id)
    entry.flight = false
    outbox->Array.push(entry)
    outbox->Array.sort((a, b) => a.seq -. b.seq)
    syncPending()
    pushPending()
  }

  // Join or un-join optimistic upserts on every in-memory query.
  let upsert = value => {
    let vid = id(value)
    itemById->Dict.set(vid, value)
    entries->Dict.forEach(entry =>
      if matches(entry.query, value) {
        switch idsByKey->Dict.get(entry.key) {
        | Some(ids) if !(ids->Array.includes(vid)) =>
          idsByKey->Dict.set(entry.key, ids->Array.concat([vid]))
        | _ => ()
        }
        switch registry->Dict.get(entry.key) {
        | Some(record) if !(record.ids->Array.includes(vid)) =>
          record.ids = record.ids->Array.concat([vid])
          persistRecord(record)
        | _ => ()
        }
      } else {
        switch idsByKey->Dict.get(entry.key) {
        | Some(ids) if ids->Array.includes(vid) =>
          idsByKey->Dict.set(entry.key, ids->Array.filter(i => i !== vid))
        | _ => ()
        }
        switch registry->Dict.get(entry.key) {
        | Some(record) if record.ids->Array.includes(vid) =>
          record.ids = record.ids->Array.filter(i => i !== vid)
          persistRecord(record)
        | _ => ()
        }
      }
    )
    switch local {
    | Some(local) =>
      let listed = ref(false)
      registry->Dict.forEach(record =>
        if record.ids->Array.includes(vid) {
          listed := true
        }
      )
      if !listed.contents {
        // A synthetic record keeps an otherwise unreferenced row reachable.
        let record = {key: syntheticPrefix ++ vid, query: None, ids: [vid], lastSeen: now()}
        registry->Dict.set(record.key, record)
        persistRecord(record)
      }
      local.push([Upsert({value: value})])
    | None => ()
    }
    enqueue(Upsert({value: value}))
  }

  // Remove optimistically from memory, loaded query records, and local storage.
  let remove = rid => {
    itemById->Dict.delete(rid)
    idsByKey->Dict.forEachWithKey((ids, key) =>
      if ids->Array.includes(rid) {
        idsByKey->Dict.set(key, ids->Array.filter(i => i !== rid))
      }
    )
    registry->Dict.forEach(record =>
      if record.ids->Array.includes(rid) {
        record.ids = record.ids->Array.filter(i => i !== rid)
        persistRecord(record)
      }
    )
    switch local {
    | Some(local) => local.push([Remove({id: rid})])
    | None => ()
    }
    enqueue(Remove({id: rid}))
  }

  // Boot: reload the persisted outbox, oldest first, and replay if online.
  switch local {
  | None => ()
  | Some(local) =>
    local.get(~tag=outboxTag, ~set=values => {
      values->Array.forEach(value =>
        switch parseOp(value) {
        | Some(entry) =>
          outbox->Array.push(entry)
          nextSeq := Math.max(nextSeq.contents, entry.seq +. 1.0)
        | None => ()
        }
      )
      outbox->Array.sort((a, b) => a.seq -. b.seq)
      syncPending()
      pushPending()
    })
  }

  let clearOnline = Tilia.watch(
    () => remote.online.value,
    online => {
      if online {
        // Reconnect: replay the outbox.
        pushPending()
      } else {
        entries->Dict.forEach(entry => {
          // Going offline frees the refresh slot for the next reconnect.
          entry.fetchedAt = 0.0
          switch getResult(results, entry) {
          | Loading => results->Dict.set(entry.key, NotLocal)
          | _ => ()
          }
        })
      }
    },
  )

  let fetch = makeFetch(remote, local, loaded, results, now)
  let getEntry = makeGetEntry(fetch, entries, results, key, now)

  // Drop a rejection for good: forget its persisted op and refetch remote truth.
  let discard = (rejection: rejection<'a>) => {
    let entry = takeRejected(rejection.id)
    switch local {
    | Some(local) => local.set(~tag=outboxTag, ~key=Float.toString(entry.seq), None)
    | None => ()
    }
    switch entry.op {
    | Upsert(_) =>
      entries->Dict.forEach(e =>
        if idsByKey->Dict.get(e.key)->Option.getOr([])->Array.includes(rejection.id) {
          fetch(e)
        }
      )
    | Remove(_) =>
      // A discarded remove is in no result: refresh every observed query instead.
      let live = observedKeys(results)
      entries->Dict.forEach(e =>
        if live->Set.has(e.key) {
          fetch(e)
        }
      )
    }
  }

  let lastPurgeAt = ref(Float.Constants.negativeInfinity)
  let purgeLocal = t =>
    switch local {
    | None => ()
    | Some(local) =>
      local.get(~tag=queryTag, ~set=values => {
        // Merge only persisted queries absent from the write-through mirror.
        values->Array.forEach(value =>
          switch parseRecord(value) {
          | Some(record) if registry->Dict.get(record.key)->Option.isNone =>
            registry->Dict.set(record.key, record)
          | _ => ()
          }
        )
        // Adopt homeless rows: a matching real query replaces the synthetic root.
        registry
        ->Dict.keysToArray
        ->Array.filter(rkey => rkey->String.startsWith(syntheticPrefix))
        ->Array.forEach(rkey => {
          let rid = rkey->String.slice(~start=syntheticPrefix->String.length)
          switch itemById->Dict.get(rid) {
          | None => () // Value unknown (earlier session): keep the synthetic root.
          | Some(value) =>
            let adopted = ref(false)
            registry->Dict.forEach(
              record =>
                switch record.query {
                | Some(query) if matches(query, value) =>
                  if !(record.ids->Array.includes(rid)) {
                    record.ids = record.ids->Array.concat([rid])
                    persistRecord(record)
                  }
                  adopted := true
                | _ => ()
                },
            )
            if adopted.contents {
              registry->Dict.delete(rkey)
              local.set(~tag=queryTag, ~key=rkey, None)
            }
          }
        })
        // Retain records for queries still in memory.
        registry->Dict.forEach(record =>
          if t > record.lastSeen + expiry.local && entries->Dict.get(record.key)->Option.isNone {
            registry->Dict.delete(record.key)
            local.set(~tag=queryTag, ~key=record.key, None)
          }
        )
        // Mark and sweep: a row stays only while some record lists it.
        local.ids(~set=allIds => {
          let marked = Set.make()
          registry->Dict.forEach(record => record.ids->Array.forEach(id => marked->Set.add(id)))
          // Pending and rejected ops root their rows: both replay after restart.
          outbox->Array.forEach(entry => marked->Set.add(opId(entry.op)))
          rejectedOps->Dict.forEach(entry => marked->Set.add(opId(entry.op)))
          let removes =
            allIds->Array.filterMap(id => marked->Set.has(id) ? None : Some(Remove({id: id})))
          if removes->Array.length > 0 {
            local.push(removes)
          }
        })
      })
    }

  let tick = () => {
    let t = now()
    // Online refreshes get a buffer to avoid a brief local-freshness flip.
    let buffer = remote.online.value ? expiry.refresh / 8.0 : 0.0
    let freshLimit = t - expiry.refresh - buffer
    let live = observedKeys(results)
    let online = remote.online.value
    // Stamp live entries before expiry so only unobserved entries can drop.
    let dropped = []
    entries->Dict.forEach(entry => {
      if live->Set.has(entry.key) {
        entry.lastSeen = t
        // Persist observation without deliveries at most once per refresh window.
        switch registry->Dict.get(entry.key) {
        | Some(record) if t > record.lastSeen + expiry.refresh =>
          record.lastSeen = t
          persistRecord(record)
        | _ => ()
        }
      }
      if t > entry.lastSeen + expiry.memory {
        dropped->Array.push(entry.key)
      } else if entry.state === LoadedRemote {
        if (
          online &&
          entry.refreshedAt < t - expiry.refresh &&
          // A hung refresh frees its slot after one refresh window.
          entry.fetchedAt < t - expiry.refresh &&
          t < entry.lastSeen + expiry.refresh
        ) {
          fetch(entry)
        }
        switch getResult(results, entry) {
        | Loaded({data, local: false}) =>
          if entry.refreshedAt < freshLimit {
            results->Dict.set(entry.key, Loaded({data, local: true}))
          }
        | _ => ()
        }
      }
    })
    if dropped->Array.length > 0 {
      // Keep items referenced by another query or unattached optimistic upserts.
      let orphans = Set.make()
      dropped->Array.forEach(key => {
        idsByKey->Dict.get(key)->Option.getOr([])->Array.forEach(id => orphans->Set.add(id))
        entries->Dict.delete(key)
        results->Dict.delete(key)
        idsByKey->Dict.delete(key)
      })
      idsByKey->Dict.forEach(ids => ids->Array.forEach(id => orphans->Set.delete(id)->ignore))
      orphans->Set.forEach(id => itemById->Dict.delete(id))
    }
    if t > lastPurgeAt.contents + expiry.local / 8.0 {
      lastPurgeAt := t
      purgeLocal(t)
    }
  }

  {
    one: makeOne(getEntry, results),
    array: makeArray(getEntry, results),
    upsert,
    remove,
    receive: {changed: _values => (), removed: _ids => ()},
    status,
    retry,
    discard,
    tick,
    dispose: clearOnline,
    _canopy: () => {
      let {live, idle}: Tilia.canopy = Tilia._canopy(results)
      {live: live->Set.toArray, idle: idle->Set.toArray}
    },
    // Testing hook: return a copy so tests cannot mutate query state.
    _ids: query => idsByKey->Dict.get(key(query))->Option.map(ids => ids->Array.map(id => id)),
  }
}
