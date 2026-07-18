// === PUBLIC TYPES (from .resi file)

@tag("state")
type loadable<'a> =
  | @as("loading") Loading
  | @as("loaded") Loaded({data: 'a, fresh: bool})
  | @as("notFound") NotFound
  | @as("notLocal") NotLocal
  | @as("failed") Failed({message: string})

@tag("op")
type op<'a> =
  | @as("upsert") Upsert({value: 'a})
  | @as("remove") Remove({id: string})

@tag("rejection")
type rejection<'a> =
  | @as("createConflict") CreateConflict({edited: 'a})
  | @as("createFailed") CreateFailed({edited: 'a, message: string})
  | @as("updateConflict") UpdateConflict({base: 'a, edited: 'a})
  | @as("updateFailed") UpdateFailed({base: 'a, edited: 'a, message: string})
  | @as("removeConflict") RemoveConflict({base: 'a})
  | @as("removeFailed") RemoveFailed({base: 'a, message: string})

@tag("change")
type change<'a> =
  | @as("clean") Clean({value: 'a})
  | @as("created") Created({edited: 'a})
  | @as("updated") Updated({base: 'a, edited: 'a})
  | @as("removed") Removed({base: 'a})
module Channel = {
  type read<'a> = {
    set: array<'a> => unit,
    live: array<'a> => unit,
    fail: string => unit,
    end: unit => unit,
    finally: (unit => unit) => unit,
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
  pending: int,
  rejected: array<rejection<'a>>,
}

type remote<'query, 'a> = {
  online: Tilia.signal<bool>,
  fetch: ('query, Channel.read<'a>) => unit,
  push: (array<op<'a>>, Channel.write<'a>) => unit,
}

type local<'query, 'a> = {
  fetch: ('query, Channel.local<'a>) => unit,
  push: array<op<'a>> => unit,
  set: (~tag: string, ~key: string, option<string>) => unit,
  get: (~tag: string, ~key: string=?, ~set: array<string> => unit) => unit,
  ids: (~set: array<string> => unit) => unit,
}

type config<'query, 'a> = {
  id: 'a => string,
  matches: ('query, 'a) => bool,
  remote: remote<'query, 'a>,
  local?: local<'query, 'a>,
  expiry?: expiry,
  now?: unit => float,
  key?: 'query => string,
  sort?: 'query => array<'a> => array<'a>,
  merge?: (~change: change<'a>, ~remote: 'a) => bool,
}

type receive<'a> = {
  changed: array<'a> => unit,
  removed: array<string> => unit,
}

type canopy = {
  live: array<string>,
  idle: array<string>,
}

type t<'query, 'a> = {
  one: 'query => loadable<'a>,
  array: 'query => loadable<array<'a>>,
  upsert: 'a => unit,
  remove: string => unit,
  receive: receive<'a>,
  status: status<'a>,
  dismiss: rejection<'a> => unit,
  tick: unit => unit,
  dispose: unit => unit,
  _canopy: unit => canopy,
}

// === Mutations (outbox)

/** A queued write, ordered by `seq` and guarded from duplicate pushes by `flight`. */
type outboxOp<'a> = {
  seq: float,
  mutable op: op<'a>,
  mutable change: option<change<'a>>,
  mutable flight: bool,
}

/** The persisted form drops the transient `flight` flag. */
let encodeOp: outboxOp<'a> => string = %raw(`
function encodeOp(entry) {
  return JSON.stringify({seq: entry.seq, op: entry.op, change: entry.change});
}`)

/** Returns None on malformed kv data: the entry is skipped, not fatal. */
let parseOp: string => option<outboxOp<'a>> = %raw(`
function parseOp(value) {
  try {
    const r = JSON.parse(value);
    if (
      r &&
      typeof r.seq === "number" &&
      r.op &&
      (r.op.op === "upsert" || r.op.op === "remove") &&
      (r.change ? typeof r.change.change === "string" : r.op.op === "remove")
    ) {
      return {seq: r.seq, op: r.op, change: r.change, flight: false};
    }
  } catch (_) {}
  return undefined;
}`)

// === Query records (registry)

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

// === Read

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
  /**
   * Closes the entry's latest fetch: late callbacks become noops and the
   * registered cleanup runs once. Idempotent.
   */
  mutable close: unit => unit,
}

/** Keys of the queries whose result is currently observed ("open"). */
let observedKeys = results => Tilia._canopy(results).live

/** Missing key means the entry was never created: treat as still loading. */
let getResult = (results, entry: entry<'query>) =>
  results->Dict.get(entry.key)->Option.getOr(Loading)

let makeFetch = (remote, local, loaded, results, now) =>
  entry => {
    // A live entry keeps its source until it ends, is superseded or expires.
    if entry.state !== LiveRemote {
      // Close the superseded fetch: its late callbacks become noops.
      entry.close()
      // One flag per fetch: every callback below is a noop once it is false.
      let active = ref(true)
      let cleanup = ref(() => ())
      let close = () =>
        if active.contents {
          active := false
          let clean = cleanup.contents
          cleanup := (() => ())
          clean()
        }
      entry.close = close

      let unknown = () => {
        if active.contents && !remote.online.value && entry.state == Pristine {
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
                if active.contents && entry.state == Pristine {
                  entry.state = LoadedLocal
                  loaded(entry, values, false)
                }
              },
              unknown: () => unknown(),
            },
          )
        }
      }

      if remote.online.value {
        entry.fetchedAt = now()
        remote.fetch(
          entry.query,
          {
            set: values => {
              if active.contents {
                entry.state = LoadedRemote
                loaded(entry, values, true)
              }
            },
            live: values => {
              if active.contents {
                entry.state = LiveRemote
                loaded(entry, values, true)
              }
            },
            fail: message => {
              if active.contents {
                results->Dict.set(entry.key, Failed({message: message}))
              }
            },
            end: () => {
              if active.contents {
                // Only a live entry is demoted: `end` on a fetch that never
                // delivered must not stamp LoadedRemote on a Loading result.
                if entry.state === LiveRemote {
                  entry.state = LoadedRemote
                }

                // Free the refresh slot, like going offline does.
                entry.fetchedAt = 0.0

                // Teardown runs last: a throwing cleanup must not block the
                // return to periodic refresh.
                close()
              }
            },
            finally: fn => {
              if active.contents {
                // Single slot, last write wins.
                cleanup := fn
              } else {
                // The fetch is already closed: run the teardown right away.
                fn()
              }
            },
          },
        )
      }
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
        close: () => (),
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
    | Loaded({data, fresh}) =>
      switch data->Array.get(0) {
      | Some(value) => Loaded({data: value, fresh})
      | None => NotFound
      }
    | Loading => Loading
    | NotFound => NotFound
    | NotLocal => NotLocal
    | Failed({message}) => Failed({message: message})
    }

let makeArray = (getEntry, results) => query => getResult(results, getEntry(query))

// === make (factory)

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
let _no_sort = _query => array => array

let make = (
  {id, matches, remote, ?local, ?expiry, ?now, ?key, ?sort, ?merge}: config<'query, 'a>,
) => {
  let expiry = expiry->Option.getOr(_expiry)
  let now = now->Option.getOr(_now)
  let key = key->Option.getOr(sortedStringify)
  let sort = sort->Option.getOr(_no_sort)
  let itemById: dict<'a> = Dict.make()->Tilia.tilia
  let idsByKey: dict<array<string>> = Dict.make()->Tilia.tilia

  let entries: dict<entry<'query>> = Dict.make()
  let results: dict<loadable<array<'a>>> = Dict.make()->Tilia.tilia

  // The write-through registry wins over older persisted records during purge.
  let queryTag = "query"
  let syntheticPrefix = "__id:"
  let registry: dict<queryRecord<'query>> = Dict.make()
  let persistRecord = (record: queryRecord<'query>) =>
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
  let (pending_, setPending) = Tilia.signal(0)
  let status: status<'a> = Tilia.tilia({pending: Tilia.lift(pending_), rejected: []})
  let outboxTag = "outbox"
  let outbox: array<outboxOp<'a>> = []
  let nextSeq = ref(0.0)
  let syncPending = () => setPending(outbox->Array.length)

  let opId = (op: op<'a>) =>
    switch op {
    | Upsert({value}) => id(value)
    | Remove({id}) => id
    }

  let rejectionId = rejection =>
    switch rejection {
    | CreateConflict({edited: record})
    | CreateFailed({edited: record})
    | UpdateConflict({edited: record})
    | UpdateFailed({edited: record})
    | RemoveConflict({base: record})
    | RemoveFailed({base: record}) =>
      id(record)
    }

  let addRejection = rejection => {
    let rid = rejectionId(rejection)
    switch status.rejected->Array.findIndex(value => rejectionId(value) === rid) {
    | -1 => status.rejected->Array.push(rejection)
    | i => status.rejected->Array.set(i, rejection)
    }
  }

  let persistOp = (entry: outboxOp<'a>) =>
    switch local {
    | Some(local) =>
      local.set(~tag=outboxTag, ~key=Float.toString(entry.seq), Some(encodeOp(entry)))
    | None => ()
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

  let pending = rid => outbox->Array.find(entry => opId(entry.op) === rid)

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
    outbox->Array.reduce(values, (values, {op}) => apply(values, op))
  }

  let join = value => {
    let vid = id(value)
    let joined = ref(false)
    entries->Dict.forEach(entry =>
      if matches(entry.query, value) {
        joined := true
        switch idsByKey->Dict.get(entry.key) {
        | Some(ids) if !(ids->Array.includes(vid)) =>
          // Do not mutate in place: the value may be shared.
          idsByKey->Dict.set(entry.key, [...ids, vid])
        | _ => ()
        }
        switch registry->Dict.get(entry.key) {
        | Some(record) if !(record.ids->Array.includes(vid)) =>
          // Do not mutate in place: the value may be shared.
          record.ids = [...record.ids, vid]
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
    joined.contents
  }

  let forget = rid => {
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
  }

  let place = value => {
    itemById->Dict.set(id(value), value)
    let joined = join(value)
    switch local {
    | Some(local) => local.push([Upsert({value: value})])
    | None => ()
    }
    joined
  }

  let conflict = change =>
    switch change {
    | Created({edited}) => CreateConflict({edited: edited})
    | Updated({base, edited}) => UpdateConflict({base, edited})
    | Removed({base}) => RemoveConflict({base: base})
    | Clean(_) => throw(Invalid_argument("clean values cannot conflict"))
    }

  let failed = (change, message) =>
    switch change {
    | Created({edited}) => CreateFailed({edited, message})
    | Updated({base, edited}) => UpdateFailed({base, edited, message})
    | Removed({base}) => RemoveFailed({base, message})
    | Clean(_) => throw(Invalid_argument("clean values cannot fail"))
    }

  let merged = (change, remoteValue) =>
    switch merge {
    | None => false
    | Some(merge) =>
      let accepted = ref(false)
      Tilia.batch(() => accepted := merge(~change, ~remote=remoteValue))
      accepted.contents
    }

  let reconcile = remoteValue => {
    let rid = id(remoteValue)
    switch pending(rid) {
    | Some(entry) =>
      switch entry.change {
      | None =>
        confirmed(entry)
        remoteValue
      | Some(change) =>
        if merged(change, remoteValue) {
          let (next, value) = switch change {
          | Created({edited})
          | Updated({edited}) => (Updated({base: remoteValue, edited}), edited)
          | Removed({base}) => (Removed({base: base}), base)
          | Clean({value}) => (Clean({value: value}), value)
          }
          entry.change = Some(next)
          switch next {
          | Updated({edited}) => entry.op = Upsert({value: edited})
          | _ => ()
          }
          persistOp(entry)
          value
        } else {
          confirmed(entry)
          addRejection(conflict(change))
          remoteValue
        }
      }
    | None =>
      switch itemById->Dict.get(rid) {
      | Some(current) if merged(Clean({value: current}), remoteValue) => current
      | _ => remoteValue
      }
    }
  }

  let loaded = (entry, values, remote) => {
    let values = remote ? applyPending(entry, values->Array.map(reconcile)) : values
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
    let build = () => {
      let values =
        idsByKey
        ->Dict.get(entry.key)
        ->Option.getOr([])
        ->Array.filterMap(id => itemById->Dict.get(id))
      // Observe sorting so edits to sort keys update the list.
      sort(entry.query)(values)
    }
    results->Dict.set(entry.key, Loaded({data: Tilia.computed(build), fresh: remote}))
  }

  // One push carries every pending op not already in flight, in order.
  let pushPending = () =>
    if remote.online.value {
      let batch = outbox->Array.filter(entry => !entry.flight)
      if batch->Array.length > 0 {
        batch->Array.forEach(entry => entry.flight = true)
        let settled = ref(false)
        remote.push(
          batch->Array.map(entry => entry.op),
          {
            set: value => {
              if !settled.contents {
                let vid = id(value)
                let match = batch->Array.find(entry =>
                  outbox->Array.includes(entry) &&
                    switch entry.op {
                    | Upsert({value}) => id(value) === vid
                    | Remove(_) => false
                    }
                )
                switch match {
                | Some(entry) =>
                  let value = switch merge {
                  | Some(_) => reconcile(value)
                  | None =>
                    confirmed(entry)
                    value
                  }
                  place(value)->ignore
                  if outbox->Array.includes(entry) {
                    confirmed(entry)
                  }
                | None => ()
                }
              }
            },
            removed: rid => {
              if !settled.contents {
                let match = batch->Array.find(entry =>
                  outbox->Array.includes(entry) &&
                    switch entry.op {
                    | Remove({id}) => id === rid
                    | Upsert(_) => false
                    }
                )
                switch match {
                | Some(entry) => confirmed(entry)
                | None => ()
                }
              }
            },
            retry: () => {
              if !settled.contents {
                settled := true
                batch->Array.forEach(entry =>
                  if outbox->Array.includes(entry) {
                    entry.flight = false
                  }
                )
              }
            },
            fail: message => {
              if !settled.contents {
                settled := true
                Tilia.batch(() => {
                  for i in batch->Array.length - 1 downto 0 {
                    switch batch[i] {
                    | Some(entry) if outbox->Array.includes(entry) =>
                      let change = entry.change
                      confirmed(entry)
                      switch change {
                      | Some(Created({edited})) => forget(id(edited))
                      | Some(Updated({base}))
                      | Some(Removed({base})) =>
                        place(base)->ignore
                      | Some(Clean(_))
                      | None => ()
                      }
                      switch change {
                      | Some(change) => addRejection(failed(change, message))
                      | None => ()
                      }
                    | _ => ()
                    }
                  }
                })
              }
            },
          },
        )
      }
    }

  let enqueue = (change, op: op<'a>) => {
    let entry = switch pending(opId(op)) {
    | Some(current) =>
      let entry = {seq: current.seq, op, change, flight: false}
      let i = outbox->Array.indexOf(current)
      outbox->Array.splice(~start=i, ~remove=1, ~insert=[entry])
      entry
    | None =>
      let seq = Math.max(now(), nextSeq.contents)
      nextSeq := seq +. 1.0
      let entry = {seq, op, change, flight: false}
      outbox->Array.push(entry)
      entry
    }
    persistOp(entry)
    syncPending()
    pushPending()
  }

  // Join or un-join optimistic upserts on every in-memory query.
  let upsert = value => {
    let vid = id(value)
    let change = switch pending(vid) {
    | Some({change: Some(Created(_))}) => Created({edited: value})
    | Some({change: Some(Updated({base}))})
    | Some({change: Some(Removed({base}))}) =>
      Updated({base, edited: value})
    | Some({change: Some(Clean({value: base}))}) => Updated({base, edited: value})
    | Some({change: None}) => Created({edited: value})
    | None =>
      switch itemById->Dict.get(vid) {
      | Some(base) => Updated({base, edited: value})
      | None => Created({edited: value})
      }
    }
    itemById->Dict.set(vid, value)
    join(value)->ignore
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
    enqueue(Some(change), Upsert({value: value}))
  }

  // Remove optimistically from memory, loaded query records, and local storage.
  let remove = rid => {
    switch pending(rid) {
    | Some(entry) =>
      switch entry.change {
      | Some(Created(_)) if !entry.flight =>
        confirmed(entry)
        forget(rid)
      | Some(Created(_))
      | None =>
        forget(rid)
        enqueue(None, Remove({id: rid}))
      | Some(Updated({base}))
      | Some(Clean({value: base})) =>
        forget(rid)
        enqueue(Some(Removed({base: base})), Remove({id: rid}))
      | Some(Removed(_)) => ()
      }
    | None =>
      let change = itemById->Dict.get(rid)->Option.map(base => Removed({base: base}))
      forget(rid)
      enqueue(change, Remove({id: rid}))
    }
  }

  // Server truth for one row, joined like an upsert. The row stays in RAM
  // only while some in-memory query matches it, and is persisted only while
  // some query record lists it. Freshness is untouched: fresh / refresh
  // scheduling stay owned by the per-query read channel.
  let receiveChanged = values =>
    values->Array.forEach(value => {
      let value = reconcile(value)
      let vid = id(value)
      switch pending(vid) {
      | Some({op: Remove(_)}) => forget(vid)
      | _ =>
        itemById->Dict.set(vid, value)
        if !join(value) {
          itemById->Dict.delete(vid)
        }
        switch local {
        | Some(local) =>
          let listed = ref(false)
          registry->Dict.forEach(record =>
            if record.ids->Array.includes(vid) {
              listed := true
            }
          )
          if listed.contents {
            local.push([Upsert({value: value})])
          }
        | None => ()
        }
      }
    })

  let receiveRemoved = ids =>
    Tilia.batch(() =>
      ids->Array.forEach(rid => {
        switch pending(rid) {
        | Some(entry) =>
          let change = entry.change
          confirmed(entry)
          switch change {
          | Some(Created({edited})) => addRejection(CreateConflict({edited: edited}))
          | Some(Updated({base, edited})) => addRejection(UpdateConflict({base, edited}))
          | Some(Removed(_))
          | Some(Clean(_))
          | None => ()
          }
        | None => ()
        }
        forget(rid)
      })
    )

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

  let fetch = makeFetch(remote, local, loaded, results, now)
  let getEntry = makeGetEntry(entry => fetch(entry), entries, results, key, now)

  let clearOnline = Tilia.watch(
    () => remote.online.value,
    online => {
      if online {
        // Reconnect every query that does not still have a live source.
        entries->Dict.forEach(entry => fetch(entry))
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

  let dismiss = rejection => {
    let i = status.rejected->Array.indexOf(rejection)
    if i >= 0 {
      status.rejected->Array.splice(~start=i, ~remove=1, ~insert=[])
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
          // Pending ops root their rows because they replay after restart.
          outbox->Array.forEach(entry => marked->Set.add(opId(entry.op)))
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
        dropped->Array.push(entry)
      } else {
        // A failed fetch re-enters the refresh loop whatever state produced
        // it; a live source owns its own recovery (a later delivery or `end`).
        let failed = switch getResult(results, entry) {
        | Failed(_) => true
        | _ => false
        }
        if (
          (entry.state === LoadedRemote || (failed && entry.state !== LiveRemote)) &&
          online &&
          entry.refreshedAt < t - expiry.refresh &&
          // A hung refresh frees its slot after one refresh window.
          entry.fetchedAt < t - expiry.refresh &&
          t < entry.lastSeen + expiry.refresh
        ) {
          fetch(entry)
        }
        if entry.state === LoadedRemote {
          switch getResult(results, entry) {
          | Loaded({data, fresh: true}) =>
            if entry.refreshedAt < freshLimit {
              results->Dict.set(entry.key, Loaded({data, fresh: false}))
            }
          | _ => ()
          }
        }
      }
    })
    if dropped->Array.length > 0 {
      // Keep items referenced by another query or unattached optimistic upserts.
      let orphans = Set.make()
      dropped->Array.forEach(entry => {
        // Stop a still-open source (e.g. a live subscription) before eviction.
        entry.close()
        let key = entry.key
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
    receive: {changed: receiveChanged, removed: receiveRemoved},
    status,
    dismiss,
    tick,
    dispose: () => {
      clearOnline()
      // Stop every still-open source. Cached values are left to normal expiry.
      entries->Dict.forEach(entry => entry.close())
    },
    _canopy: () => {
      let {live, idle}: Tilia.canopy = Tilia._canopy(results)
      {live: live->Set.toArray, idle: idle->Set.toArray}
    },
  }
}
