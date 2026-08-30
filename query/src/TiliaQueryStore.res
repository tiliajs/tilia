// B+C · the store this package ships: a write-through cache with an outbox.
// It owns optimistic writes, the three-way merge, rejections, durable rows,
// the query registry and local expiry, and it answers the engine's finds from
// local storage first and the remote after. Another store — a database that
// keeps itself in sync — replaces the whole of it, which is why the engine
// never reaches past `source`.

// `Dict` and `Arr` are the shadowing bindings the whole package reads
// through; the shadow is the point.
@@warning("-44")
open TiliaQuerySchema

open TiliaQueryEngine

@tag("op")
type op<'a> =
  | @as("upsert") Upsert({value: 'a})
  | @as("remove") Remove({id: string})

@tag("change")
type change<'a> =
  | @as("clean") Clean({value: 'a})
  | @as("created") Created({edited: 'a})
  | @as("updated") Updated({base: 'a, edited: 'a})
  | @as("removed") Removed({base: 'a})

@tag("rejection")
type rejection<'a> =
  | @as("createConflict") CreateConflict({edited: 'a})
  | @as("createFailed") CreateFailed({edited: 'a, message: string})
  | @as("updateConflict") UpdateConflict({base: 'a, edited: 'a})
  | @as("updateFailed") UpdateFailed({base: 'a, edited: 'a, message: string})
  | @as("removeConflict") RemoveConflict({base: 'a})
  | @as("removeFailed") RemoveFailed({base: 'a, message: string})

type status<'a> = {
  pending: int,
  rejected: array<rejection<'a>>,
}

type receive<'a> = {
  changed: array<'a> => unit,
  removed: array<string> => unit,
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

/** Returns Undefined on malformed kv data: the entry is skipped, not fatal. */
let parseOp: string => nullable<outboxOp<'a>> = %raw(`
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

/**
 * Deep copy through the store contract: values are already required to
 * survive a JSON round trip, so nothing new is asked of them here.
 */
let snapshot: 'a => 'a = %raw(`
function snapshot(value) {
  return JSON.parse(JSON.stringify(value));
}`)

// === Query records (registry)

/** Durable query result used to find rows still reachable during local purge. */
type queryRecord<'query> = {
  key: string,
  // The query itself, so matches can run on disk-only records. Undefined on synthetics.
  query: nullable<'query>,
  mutable ids: array<string>,
  mutable lastSeen: float,
}

@scope("JSON") @val external encodeRecord: queryRecord<'query> => string = "stringify"

/** Returns Undefined on malformed kv data: the entry is skipped, not fatal. */
let parseRecord: string => nullable<queryRecord<'query>> = %raw(`
function parseRecord(value) {
  try {
    const r = JSON.parse(value);
    if (r && typeof r.key === "string" && Array.isArray(r.ids) && typeof r.lastSeen === "number") {
      return r;
    }
  } catch (_) {}
  return undefined;
}`)

/** Configuration for `connect`. */
type config<'query, 'a> = {
  schema: schema<'query, 'a>,
  expiry: expiry,
  remote: remote<'query, 'a>,
  local?: local<'query, 'a>,
  merge?: (~change: change<'a>, ~remote: 'a) => bool,
}

type t<'query, 'a> = {
  upsert: 'a => unit,
  remove: string => unit,
  receive: receive<'a>,
  status: status<'a>,
  retry: rejection<'a> => unit,
  discard: rejection<'a> => unit,
  tick: unit => unit,
  dispose: unit => unit,
}

/** Build the store around a binding that already works, and hand back the
 source the engine will read from. The outbox replay belongs here, in the
 store's own construction. */
let connect = (
  {schema, expiry, remote, ?local, ?merge}: config<'query, 'a>,
  binding: binding<'a>,
) => {
  let {id, matches, key, now, _} = schema

  // The write-through registry wins over older persisted records during purge.
  let queryTag = "query"
  let syntheticPrefix = "__id:"
  let registry: dict<queryRecord<'query>> = Dict.make()
  let persistRecord = (record: queryRecord<'query>) =>
    switch local {
    | None => ()
    | Some(local) => local.set(~tag=queryTag, ~key=record.key, Some(encodeRecord(record)))
    }
  // The queries the engine holds in memory, and when each was last asked
  // for. A query is held from its first find until `forget`, which is the
  // store's only view of what is still on screen: the registry is maintained
  // for these, and their records are never purged.
  let held: dict<'query> = Dict.make()
  let lastFindAt: dict<float> = Dict.make()
  // The strongest claim a held query has been recorded from. The engine
  // refuses a weakened answer and so does the record behind it: local
  // storage answering a refresh must not put back what the remote dropped.
  let recorded: dict<claim> = Dict.make()
  let findAt = k =>
    switch lastFindAt->Dict.get(k) {
    | Value(t) => t
    | Null | Undefined => 0.0
    }

  // A late delivery must not extend the retention of an unobserved query, so
  // a record is dated by the find that asked for it, never by the answer.
  let recordSeen = (k, query, claim, ids) => {
    let weaker = switch recorded->Dict.get(k) {
    | Value(current) => rank(claim) < rank(current)
    | Null | Undefined => false
    }
    switch local {
    | None => ()
    | Some(_) if weaker => ()
    | Some(_) =>
      recorded->Dict.set(k, claim)
      let record = switch registry->Dict.get(k) {
      | Value(record) => record
      | Null | Undefined =>
        let record = {key: k, query: Value(query), ids: [], lastSeen: 0.0}
        registry->Dict.set(k, record)
        record
      }
      record.lastSeen = Math.max(record.lastSeen, findAt(k))
      record.ids = ids
      persistRecord(record)
    }
  }

  // B · which query records list this row, and whether any of them does —
  // the answer decides whether local storage keeps a copy. Only records for
  // held queries are maintained here; a record for a query that left memory
  // is repaired by the purge instead.
  let joinRegistry = value => {
    let vid = id(value)
    held->Dict.forEachWithKey((query, k) =>
      switch registry->Dict.get(k) {
      | Value(record) =>
        if matches(query, value) {
          if !(record.ids->Array.includes(vid)) {
            // Do not mutate in place: the value may be shared.
            record.ids = record.ids->Array.concat([vid])
            persistRecord(record)
          }
        } else if record.ids->Array.includes(vid) {
          record.ids = record.ids->Array.filter(i => i !== vid)
          persistRecord(record)
        }
      | Null | Undefined => ()
      }
    )
    let listed = ref(false)
    registry->Dict.forEach(record =>
      if record.ids->Array.includes(vid) {
        listed := true
      }
    )
    listed.contents
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

  // The operation each rejection stands for, so the list can be ordered by
  // it rather than by the order replies happen to arrive in. Private: the
  // seq is bookkeeping, not something an app should read off a rejection.
  let rejectionSeq: dict<float> = Dict.make()
  let seqOf = rejection =>
    switch rejectionSeq->Dict.get(rejectionId(rejection)) {
    | Value(seq) => seq
    | Null | Undefined => 0.0
    }

  let addRejection = (~seq, rejection) => {
    let rid = rejectionId(rejection)
    // The single boundary where a live change becomes a historical record:
    // copy it here, so no later branch can hand out a value still in play.
    let rejection = snapshot(rejection)
    switch status.rejected->Array.findIndex(value => rejectionId(value) === rid) {
    | -1 =>
      rejectionSeq->Dict.set(rid, seq)
      switch status.rejected->Array.findIndex(value => seqOf(value) > seq) {
      | -1 => status.rejected->Array.push(rejection)
      | i => status.rejected->Array.splice(~start=i, ~remove=0, ~insert=[rejection])
      }
    // A replacement keeps the place its id already holds: the list orders the
    // work that was refused, and that work queued once.
    | i => status.rejected->Array.set(i, rejection)
    }
  }

  let dropRejection = rid =>
    switch status.rejected->Array.findIndex(value => rejectionId(value) === rid) {
    | -1 => false
    | i =>
      status.rejected->Array.splice(~start=i, ~remove=1, ~insert=[])
      rejectionSeq->Dict.delete(rid)
      true
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

  let applyPending = (query, values) => {
    let apply = (values, op) =>
      switch op {
      | Upsert({value}) =>
        let vid = id(value)
        if !matches(query, value) {
          // A pending move keeps the row out of queries it left.
          values->Array.filter(v => id(v) !== vid)
        } else if values->Array.some(v => id(v) === vid) {
          values->Array.map(v => id(v) === vid ? value : v)
        } else {
          values->Array.concat([value])
        }
      | Remove({id: rid}) => values->Array.filter(v => id(v) !== rid)
      }
    outbox->Arr.reduce((values, {op}) => apply(values, op), values)
  }

  // The store's own removal: the engine's rows, its own registry, its own
  // local copy.
  let forget = rid => {
    binding.removed([rid])
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

  // The store's own write of one row: into the engine, into the registry,
  // into local storage.
  let place = value => {
    binding.place(value)
    joinRegistry(value)->ignore
    switch local {
    | Some(local) => local.push([Upsert({value: value})])
    | None => ()
    }
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
          addRejection(~seq=entry.seq, conflict(change))
          remoteValue
        }
      }
    | None =>
      switch binding.item(rid) {
      | Some(current) if merged(Clean({value: current}), remoteValue) => current
      | _ => remoteValue
      }
    }
  }

  // One push carries every pending op not already in flight, in order.
  let pushPending = () =>
    if remote.online.value {
      let batch = outbox->Array.filter(entry => !entry.flight)
      if batch->Array.length > 0 {
        batch->Array.forEach(entry => entry.flight = true)
        let settled = ref(false)
        // `set`, `removed`, `conflict` and `reject` answer one operation.
        // `retry` and `fail` apply to every operation in the push that has
        // not been answered. Answering is not settling: `conflict` leaves the
        // operation pending so the rebased value still has to reach the
        // server.
        let answered: array<outboxOp<'a>> = []
        let waiting = entry => outbox->Array.includes(entry) && !(answered->Array.includes(entry))
        let findUpsert = vid =>
          batch->Array.find(entry =>
            waiting(entry) &&
            switch entry.op {
            | Upsert({value}) => id(value) === vid
            | Remove(_) => false
            }
          )
        let findRemove = rid =>
          batch->Array.find(entry =>
            waiting(entry) &&
            switch entry.op {
            | Remove({id}) => id === rid
            | Upsert(_) => false
            }
          )
        let findAny = rid => batch->Array.find(entry => waiting(entry) && opId(entry.op) === rid)

        // Put the local value back where the server says it never moved, and
        // keep the refused work rather than losing it.
        let revert = (entry: outboxOp<'a>, message) => {
          let change = entry.change
          confirmed(entry)
          switch change {
          | Some(Created({edited})) => forget(id(edited))
          | Some(Updated({base}))
          | Some(Removed({base})) =>
            place(base)
          | Some(Clean(_))
          | None => ()
          }
          switch change {
          | Some(change) => addRejection(~seq=entry.seq, failed(change, message))
          | None => ()
          }
        }

        remote.push(
          batch->Array.map(entry => entry.op),
          {
            set: value => {
              if !settled.contents {
                switch findUpsert(id(value)) {
                | Some(entry) =>
                  answered->Array.push(entry)
                  confirmed(entry)
                  place(value)
                | None => ()
                }
              }
            },
            removed: rid => {
              if !settled.contents {
                switch findRemove(rid) {
                | Some(entry) =>
                  answered->Array.push(entry)
                  confirmed(entry)
                | None => ()
                }
              }
            },
            conflict: value => {
              if !settled.contents {
                switch findAny(id(value)) {
                | Some(entry) =>
                  answered->Array.push(entry)
                  switch entry.change {
                  | None =>
                    // Nothing local to rebase: the server value stands.
                    confirmed(entry)
                    place(value)
                  | Some(change) =>
                    if merged(change, value) {
                      let (next, edited) = switch change {
                      | Created({edited})
                      | Updated({edited}) => (Updated({base: value, edited}), edited)
                      | Removed({base}) => (Removed({base: base}), base)
                      | Clean({value}) => (Clean({value: value}), value)
                      }
                      entry.change = Some(next)
                      switch next {
                      | Updated({edited}) => entry.op = Upsert({value: edited})
                      | _ => ()
                      }
                      persistOp(entry)

                      // Still pending: the heartbeat pushes the rebased value.
                      // Retrying here would let a server that keeps
                      // conflicting spin the outbox.
                      entry.flight = false
                      place(edited)
                    } else {
                      confirmed(entry)
                      addRejection(~seq=entry.seq, conflict(change))
                      place(value)
                    }
                  }
                | None => ()
                }
              }
            },
            reject: (rid, message) => {
              if !settled.contents {
                switch findAny(rid) {
                | Some(entry) =>
                  answered->Array.push(entry)
                  Tilia.batch(() => revert(entry, message))
                | None => ()
                }
              }
            },
            retry: () => {
              if !settled.contents {
                settled := true
                batch->Array.forEach(entry =>
                  if waiting(entry) {
                    entry.flight = false
                  }
                )
              }
            },
            fail: message => {
              if !settled.contents {
                settled := true
                // Write order: a cascade is refused cause-first, so working
                // down `status.rejected` retries the cause before the
                // consequence.
                Tilia.batch(() =>
                  batch->Array.forEach(entry =>
                    if waiting(entry) {
                      revert(entry, message)
                    }
                  )
                )
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
    // A new write on an id speaks for it: whatever was refused is history.
    dropRejection(vid)->ignore
    let change = switch pending(vid) {
    | Some({change: Some(Created(_))}) => Created({edited: value})
    | Some({change: Some(Updated({base}))})
    | Some({change: Some(Removed({base}))}) =>
      Updated({base, edited: value})
    | Some({change: Some(Clean({value: base}))}) => Updated({base, edited: value})
    | Some({change: None}) => Created({edited: value})
    | None =>
      switch binding.item(vid) {
      | Some(base) => Updated({base, edited: value})
      | None => Created({edited: value})
      }
    }
    binding.place(value)
    let listed = joinRegistry(value)
    switch local {
    | Some(local) =>
      if !listed {
        // A synthetic record keeps an otherwise unreferenced row reachable.
        let record = {key: syntheticPrefix ++ vid, query: Undefined, ids: [vid], lastSeen: now()}
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
    dropRejection(rid)->ignore
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
      let change = switch binding.item(rid) {
      | Some(base) => Some(Removed({base: base}))
      | None => None
      }
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
        binding.changed([value])

        // Local storage keeps a copy only while some record lists the row.
        if joinRegistry(value) {
          switch local {
          | Some(local) => local.push([Upsert({value: value})])
          | None => ()
          }
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
          | Some(Created({edited})) =>
            addRejection(~seq=entry.seq, CreateConflict({edited: edited}))
          | Some(Updated({base, edited})) =>
            addRejection(~seq=entry.seq, UpdateConflict({base, edited}))
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
        | Value(entry) =>
          outbox->Array.push(entry)
          nextSeq := Math.max(nextSeq.contents, entry.seq +. 1.0)
        | Null | Undefined => ()
        }
      )
      outbox->Array.sort((a, b) => a.seq -. b.seq)
      syncPending()
      pushPending()
    })
  }

  // B+C · one find, both tiers, in the order the engine assumes: what is
  // already held answers first, and the remote answers over it. The store
  // owns which tiers exist; the engine only reads the claims.
  let findQuery = (query, channel: Channel.find<'a>) => {
    let k = key(query)
    let t = now()
    held->Dict.set(k, query)
    lastFindAt->Dict.set(k, t)
    // A held query keeps its record alive. The engine finds an observed
    // query again at most one refresh window apart, so this dates it about
    // as often as it is worth a write.
    switch registry->Dict.get(k) {
    | Value(record) if t > record.lastSeen + expiry.refresh =>
      record.lastSeen = t
      persistRecord(record)
    | _ => ()
    }

    // Remote truth, reconciled against what is queued before anyone sees it.
    let received = values => {
      let values = applyPending(query, values->Array.map(reconcile))
      switch local {
      | Some(local) => local.push(values->Array.map(value => Upsert({value: value})))
      | None => ()
      }
      recordSeen(k, query, Fresh, values->Array.map(id))
      values
    }

    switch local {
    | None =>
      // Nothing is held, and holding nothing is not an answer: the engine
      // reads an empty `Partial` as still loading, or as offline.
      channel.partial([])
    | Some(local) =>
      local.fetch(
        query,
        {
          // A partial answer never records a query result: it was not one.
          partial: values => channel.partial(values),
          local: values => {
            recordSeen(k, query, Local, values->Array.map(id))
            channel.local(values)
          },
        },
      )
    }

    if remote.online.value {
      remote.fetch(
        query,
        {
          fresh: values => channel.fresh(received(values)),
          live: values => channel.live(received(values)),
          fail: channel.fail,
          end: channel.end,
          finally: channel.finally,
        },
      )
    }
  }

  // Eviction, never dispose: the query left memory, so the store stops
  // maintaining its record and lets local expiry have it.
  let forgetQuery = query => {
    let k = key(query)
    held->Dict.delete(k)
    lastFindAt->Dict.delete(k)
    recorded->Dict.delete(k)
  }

  // Each half watches connectivity for its own reason.
  let clearOnlineStore = Tilia.watch(
    () => remote.online.value,
    online =>
      if online {
        pushPending()
      },
  )

  // Both act on the exact record they were handed. A stale callback holding
  // a superseded rejection must not speak for the one that replaced it.
  let take = rejection =>
    switch status.rejected->Array.indexOf(rejection) {
    | -1 => false
    | i =>
      status.rejected->Array.splice(~start=i, ~remove=1, ~insert=[])
      rejectionSeq->Dict.delete(rejectionId(rejection))
      true
    }

  let discard = rejection => take(rejection)->ignore

  // The refused work goes back through the ordinary write path, so its change
  // is computed against the value that stands now, not the one it started
  // from. Copied on the way out: the record an app may still hold is history.
  let retry = rejection =>
    if take(rejection) {
      switch rejection {
      | CreateConflict({edited})
      | CreateFailed({edited})
      | UpdateConflict({edited})
      | UpdateFailed({edited}) =>
        upsert(snapshot(edited))
      | RemoveConflict({base})
      | RemoveFailed({base}) =>
        remove(id(base))
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
          | Value(record) =>
            switch registry->Dict.get(record.key) {
            | Value(_) => ()
            | Null | Undefined => registry->Dict.set(record.key, record)
            }
          | Null | Undefined => ()
          }
        )
        // Adopt homeless rows: a matching real query replaces the synthetic root.
        registry
        ->Dict.keys
        ->Array.filter(rkey => rkey->String.startsWith(syntheticPrefix))
        ->Array.forEach(rkey => {
          let rid = rkey->String.slice(~start=syntheticPrefix->String.length)
          switch binding.item(rid) {
          | None => () // Value unknown (earlier session): keep the synthetic root.
          | Some(value) =>
            let adopted = ref(false)
            registry->Dict.forEach(
              record =>
                switch record.query {
                | Value(query) if matches(query, value) =>
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
        // Retain records for queries the engine still holds.
        registry->Dict.forEach(record =>
          switch held->Dict.get(record.key) {
          | Value(_) => ()
          | Null | Undefined =>
            if t > record.lastSeen + expiry.local {
              registry->Dict.delete(record.key)
              local.set(~tag=queryTag, ~key=record.key, None)
            }
          }
        )
        // Mark and sweep: a row stays only while some record lists it.
        local.ids(~set=allIds => {
          let marked = Set.make()
          registry->Dict.forEach(record => record.ids->Array.forEach(id => marked->Set.add(id)))
          // Pending ops root their rows because they replay after restart.
          outbox->Array.forEach(entry => marked->Set.add(opId(entry.op)))
          let removes = []
          allIds->Array.forEach(
            id =>
              if !(marked->Set.has(id)) {
                removes->Array.push(Remove({id: id}))
              },
          )
          if removes->Array.length > 0 {
            local.push(removes)
          }
        })
      })
    }

  // B+C · the store's half of the heartbeat, run after the engine's.
  let storeTick = t => {
    // Persist observation without deliveries at most once per refresh
    // window. A held query is found again at least that often, except a live
    // one, which is found once and would otherwise let its record age out.
    registry->Dict.forEachWithKey((record, k) =>
      switch held->Dict.get(k) {
      | Value(_) if t > record.lastSeen + expiry.refresh =>
        record.lastSeen = t
        persistRecord(record)
      | _ => ()
      }
    )
    // Retry transient push failures. `channel.retry()` only frees the ops; the
    // heartbeat is what decides to try again, so an app that is online and
    // idle still drains its outbox. Ops already in flight are skipped, so the
    // rate is bounded by the tick rate.
    pushPending()
    if t > lastPurgeAt.contents + expiry.local / 8.0 {
      lastPurgeAt := t
      purgeLocal(t)
    }
  }

  (
    {online: remote.online, find: findQuery, forget: forgetQuery},
    {
      upsert,
      remove,
      receive: {changed: receiveChanged, removed: receiveRemoved},
      status,
      retry,
      discard,
      tick: () => storeTick(now()),
      dispose: () => clearOnlineStore(),
    },
  )
}
