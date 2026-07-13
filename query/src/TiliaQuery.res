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

/**
 * Per-query runtime state. Results live in the shared reactive `results`
 * dict, one key per query: reads inside a `Tilia.observe` re-run when a
 * channel delivers fresher results, and a single canopy scan of the dict
 * tells which queries are observed.
 */
type entry<'query> = {
  key: string,
  query: 'query,
  mutable lastSeen: float,
  mutable refreshedAt: float,
  /** When the latest remote fetch was issued — throttles refresh to one
   * in-flight request per refresh window. Reset to 0.0 on going offline so
   * the first tick back online may refetch immediately. */
  mutable fetchedAt: float,
  mutable state: entryState,
}

/**
 * Persisted query registry record — mirrors one kv entry (tag "query").  The
 * registry drives the local purge. It outlives both the in-memory entry
 * (dropped after expiry.memory) and app restarts. `ids` holds the query's
 * latest result only. The purge is a mark and sweep:
 * - mark: every id listed by a surviving record or in the outbox;
 * - sweep: enumerate the stored rows (`local.ids`) and remove the rest.
 * local.push never removes rows on its own. So when a row is deleted on
 * the remote, it lingers in local storage — until no fresh query lists it
 * and the next sweep drops it.
 */
type queryRecord = {
  key: string,
  mutable ids: array<string>,
  mutable lastSeen: float,
}

@scope("JSON") @val external encodeRecord: queryRecord => string = "stringify"

/** Returns None on malformed kv data: the entry is skipped, not fatal. */
let parseRecord: string => option<queryRecord> = %raw(`
function parseRecord(value) {
  try {
    const r = JSON.parse(value);
    if (r && typeof r.key === "string" && Array.isArray(r.ids) && typeof r.lastSeen === "number") {
      return r;
    }
  } catch (_) {}
  return undefined;
}`)

/**
 * One outbox entry: a write not yet confirmed by the remote.
 * - `seq` orders replay and keys the persisted copy (kv tag "outbox").
 * - `flight` marks entries already handed to an in-flight `remote.push`,
 *   so a later push does not send them again.
 */
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

  let entries: dict<entry<'query>> = Dict.make()
  let results: dict<loadable<array<'a>>> = Dict.make()->Tilia.tilia

  // In-memory mirror of the persisted query registry (kv tag "query"),
  // written through on change. So for any key the mirror holds, the disk
  // copy is never fresher. The purge merges disk records only for keys the
  // mirror lacks (queries from past sessions).
  let queryTag = "query"
  let registry: dict<queryRecord> = Dict.make()
  let persistRecord = record =>
    switch local {
    | None => ()
    | Some(local) => local.set(~tag=queryTag, ~key=record.key, Some(encodeRecord(record)))
    }
  // lastSeen tracks observation (entry.lastSeen), not delivery time: a
  // late remote response landing on a long-closed query must not extend
  // its local retention.
  let recordSeen = (entry: entry<'query>, ids) =>
    switch local {
    | None => ()
    | Some(_) =>
      let record = switch registry->Dict.get(entry.key) {
      | Some(record) => record
      | None =>
        let record = {key: entry.key, ids: [], lastSeen: 0.0}
        registry->Dict.set(entry.key, record)
        record
      }
      record.lastSeen = Math.max(record.lastSeen, entry.lastSeen)
      record.ids = ids
      persistRecord(record)
    }

  let loaded = (entry, values, remote) => {
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
    // We make the entry result rebuild on changes to ids or any of the id in the list.
    let build = () =>
      idsByKey
      ->Dict.get(entry.key)
      ->Option.getOr([])
      ->Array.filterMap(id => itemById->Dict.get(id))
      ->sort // sorting must be watched so that edits to keys used by sort make the list update.
    results->Dict.set(entry.key, Loaded({data: Tilia.computed(build), local: !remote}))
  }

  // Every write (`upsert` / `remove`) enqueues its op in the outbox and
  // counts in `status.pending`. The outbox is pushed only while online —
  // `remote.push` is never called offline. A confirmation (`channel.set` /
  // `channel.removed`) drops the op from the outbox. The outbox is durable:
  // ops are persisted in the local kv and reloaded at boot, so pending
  // writes survive a restart and replay.
  let status: status<'a> = Tilia.tilia({pending: 0, rejected: []})
  let outboxTag = "outbox"
  let outbox: array<outboxOp<'a>> = []
  let nextSeq = ref(0.0)
  let syncPending = () => status.pending = outbox->Array.length

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
                // The confirmed value is authoritative (it may be
                // server-corrected): it replaces the local copies.
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
            // TODO (rejections): a definitive failure moves the unconfirmed
            // ops to `status.rejected`; until that lands, treat like retry.
            fail: _ => batch->Array.forEach(entry => entry.flight = false),
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

  let upsert = value => {
    // Optimistic: the value is visible and persisted before the remote
    // confirms.
    itemById->Dict.set(id(value), value)
    switch local {
    | Some(local) => local.push([Upsert({value: value})])
    | None => ()
    }
    enqueue(Upsert({value: value}))
  }

  // Remove is optimistic: the id leaves every in-memory query result and
  // the persisted query records, and the local row is deleted, before the
  // remote confirms. The op queues in the outbox like any write.
  // Disk-only query records from past sessions may keep listing the id:
  // harmless (the row is gone, marking a rowless id is a no-op) and
  // self-correcting on the query's next refresh.
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
          // Cancel in-flight remote fetches; free the refresh slot so the
          // first tick back online may refetch immediately.
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

  /*
    When to do what:
    Every tick, in one pass over the entries (all in-memory work); the expensive
    parts self-throttle per entry
    - record lastSeen for observed queries
    - refresh observed LoadedRemote queries (throttled by refreshedAt /
      fetchedAt)
    - flip un-refreshed remote results to `local: true`
    - drop queries unseen for expiry.memory, then items no query references
    First tick after boot, then at most every expiry.local / 8 (async kv
    I/O, so gated — sessions rarely span 3.75 days, so in practice once
    per boot):
    - local purge, a mark and sweep:
      1. merge the on-disk query registry into the mirror
      2. drop records unseen for expiry.local
      3. mark every id the surviving records list and in the outbox
      4. remove the unmarked ids from the stored rows (local.ids)
 */
  let lastPurgeAt = ref(Float.Constants.negativeInfinity)
  let purgeLocal = t =>
    switch local {
    | None => ()
    | Some(local) =>
      local.get(~tag=queryTag, ~set=values => {
        // Merge queries from past sessions. The mirror is written through,
        // so a key it already holds is at least as fresh as the disk copy.
        values->Array.forEach(value =>
          switch parseRecord(value) {
          | Some(record) if registry->Dict.get(record.key)->Option.isNone =>
            registry->Dict.set(record.key, record)
          | _ => ()
          }
        )
        // Drop records unseen for expiry.local. An in-memory entry was
        // seen within expiry.memory: never stale.
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
          // TODO (outbox): also mark the ids of pending outbox ops. A row
          // with an unconfirmed write must survive the sweep even when no
          // query lists it.
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
    // Online: one extra refresh-check period (refresh / 8) of buffer so an
    // in-flight refresh can land without a flip/flop. Offline: flip right at
    // the refresh expiry limit.
    let buffer = remote.online.value ? expiry.refresh / 8.0 : 0.0
    let freshLimit = t - expiry.refresh - buffer
    let live = observedKeys(results)
    let online = remote.online.value
    // Live entries get stamped before the expiry check, so only unobserved
    // entries can be dropped.
    let dropped = []
    entries->Dict.forEach(entry => {
      if live->Set.has(entry.key) {
        entry.lastSeen = t
        // Keep the on-disk lastSeen fresh for queries observed without
        // remote deliveries (offline), so they survive the purge across a
        // restart. At most one kv write per refresh window.
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
          // At most one in-flight refresh; a hung request frees the slot
          // after a full refresh window.
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
      // An item leaves memory only when no remaining query references it:
      // optimistic upserts not yet attached to a query are left alone.
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
    // TODO (outbox): on upsert, join the queries the record `matches`
    // (update their ids + the stored item). No dedicated per-record query:
    // while the op is pending, the sweep marks its id from the outbox;
    // after confirmation the row lives through the queries that list it.
    upsert,
    remove,
    receive: {changed: _values => (), removed: _ids => ()},
    status,
    retry: _rejection => (),
    discard: _rejection => (),
    tick,
    dispose: clearOnline,
    _canopy: () => {
      let {live, idle}: Tilia.canopy = Tilia._canopy(results)
      {live: live->Set.toArray, idle: idle->Set.toArray}
    },
    // Testing hook: return a copy so tests cannot mutate query state.
    _ids: query =>
      idsByKey->Dict.get(key(query))->Option.map(ids => ids->Array.map(id => id)),
  }
}
