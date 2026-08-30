// A · the reactive query engine. It owns the rows it has been given, which
// in-memory query lists each one, what each query currently answers, and when
// to ask for it again. It knows nothing about where an answer comes from,
// what is queued behind it, or how it is persisted: that is the store, and
// the two meet at `source` and `binding` alone.

// `Dict` and `Arr` are the shadowing bindings the whole package reads
// through; the shadow is the point.
@@warning("-44")
open TiliaQuerySchema

/**
 * Timing the engine owns, in milliseconds: how long an answer stays fresh,
 * and how long a query it no longer shows stays in memory. What local
 * storage keeps, and for how long, is the store's own business.
 */
type expiry = {
  refresh: float,
  memory: float,
}

/**
 * What the store may do to the engine's rows. `item` is a getter, not the
 * dict: the object it hands back *is* the live one, so merging in place
 * works, while a key insert or delete stays unexpressible and `idsByKey`
 * cannot fall out of step.
 *
 * `place` keeps a row whether or not a query lists it — an optimistic write
 * stands on its own. `changed` is remote truth, and keeps a row only while
 * some in-memory query matches it.
 */
type binding<'a> = {
  item: string => option<'a>,
  changed: array<'a> => unit,
  removed: array<string> => unit,
  place: 'a => unit,
}

/**
 * What the engine may ask of the store. One `find` per query, whatever tier
 * answers it: the engine does not know there are two, and asks again on
 * every refresh. `forget` says the query left memory — on eviction only,
 * never on dispose.
 */
type source<'query, 'a> = {
  online: Tilia.signal<bool>,
  find: ('query, Channel.find<'a>) => unit,
  forget: 'query => unit,
  /** The store's half of the heartbeat and of shutdown. Both cross the seam
   the same way a find does, and in the same direction: whoever holds the
   query object drives one clock and closes one thing, and the engine keeps
   the order — its own half first, so nothing is in flight against a store
   that has stopped. */
  tick: unit => unit,
  dispose: unit => unit,
}

/**
 * How a store is attached. It is given a binding that already works and
 * hands back its source in the same breath, so neither half ever exists
 * unconnected and a store may use the binding while its own constructor is
 * still running. `'store` is whatever that store offers the application —
 * opaque here, because the engine has no business knowing.
 */
type connect<'query, 'a, 'store> = binding<'a> => (source<'query, 'a>, 'store)

// === Read

type entryState = Pristine | LoadedPartial | LoadedLocal | LoadedRemote | LiveRemote

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
  switch results->Dict.get(entry.key) {
  | Value(result) => result
  | Null | Undefined => Loading
  }

let makeFind = (
  ~schema: schema<'query, 'a>,
  source: source<'query, 'a>,
  loaded,
  results,
  reportError,
) =>
  entry => {
    // A live entry keeps its source until it ends, is superseded or expires.
    if entry.state !== LiveRemote {
      // Close the superseded find: its late callbacks become noops.
      entry.close()
      // One flag per find: every callback below is a noop once it is false.
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

      // Only `tick` lowers a claim. A find that reopens is answered from the
      // store's own rows first, and that must not pull a fresh result down.
      let accept = (claim, state, values) =>
        if active.contents {
          let weaker = switch getResult(results, entry) {
          | Loaded({claim: current}) => rank(claim) < rank(current)
          | _ => false
          }
          if !weaker {
            entry.state = state
            loaded(entry, values, claim)
          }
        }

      // The store decides whether a remote is asked at all; the engine still
      // owns the refresh slot, and only a find that can reach one takes it.
      if source.online.value {
        entry.fetchedAt = schema.now()
      }

      source.find(
        entry.query,
        {
          partial: values => accept(Partial, LoadedPartial, values),
          local: values => accept(Local, LoadedLocal, values),
          fresh: values => accept(Fresh, LoadedRemote, values),
          live: values => accept(Fresh, LiveRemote, values),
          fail: message => {
            if active.contents {
              // Shown only when there is nothing else to show. The
              // discriminator is what `array` answers, not which find
              // failed: some data beats an error in place of a list, and a
              // list blinking data to error to data is worse than either.
              switch project(source.online.value, getResult(results, entry)) {
              | Loaded(_) => reportError(entry.query, message)
              | Loading
              | NoData(_) =>
                results->Dict.set(entry.key, NoData({reason: Failed({message: message})}))
              }
            }
          },
          end: () => {
            if active.contents {
              // Only a live entry is demoted: `end` on a find that never
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
              // The find is already closed: run the teardown right away.
              fn()
            }
          },
        },
      )
    }
  }

let makeGetEntry = (~schema: schema<'query, 'a>, fetch, entries, results) =>
  query => {
    let k = schema.key(query)
    switch entries->Dict.get(k) {
    | Value(entry) => entry
    | Null | Undefined =>
      let entry = {
        lastSeen: schema.now(),
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

let makeOne = (getEntry, results, online: Tilia.signal<bool>) =>
  query =>
    switch project(online.value, getResult(results, getEntry(query))) {
    | Loaded({claim, data}) =>
      switch data->Arr.at(0) {
      // An absence ages like any other answer, so it carries its claim.
      | Null | Undefined => NoData({reason: NoMatch({claim: claim})})
      | Value(value) => Loaded({claim, data: value})
      }
    | Loading => Loading
    | NoData({reason}) => NoData({reason: reason})
    }

let makeArray = (getEntry, results, online: Tilia.signal<bool>) =>
  query => project(online.value, getResult(results, getEntry(query)))

type canopy = {
  live: array<string>,
  idle: array<string>,
}

/** Configuration for `make`. The store arrives as `connect`, not as a value:
 the binding it is given cannot exist before the engine, and the engine
 cannot run without the source, so the two are tied in one call. */
type config<'query, 'a, 'store> = {
  schema: schema<'query, 'a>,
  expiry: expiry,
  onError: (~query: 'query, ~message: string) => unit,
  connect: connect<'query, 'a, 'store>,
}

type t<'query, 'a> = {
  one: 'query => loadable<'a>,
  array: 'query => loadable<array<'a>>,
  tick: unit => unit,
  dispose: unit => unit,
  _canopy: unit => canopy,
}

let make = ({schema, expiry, onError, connect}: config<'query, 'a, 'store>) => {
  let {id, matches, sort, now, _} = schema
  let reportError = (query, message) => onError(~query, ~message)

  let itemById: dict<'a> = Dict.make()->Tilia.tilia
  let idsByKey: dict<array<string>> = Dict.make()->Tilia.tilia

  let entries: dict<entry<'query>> = Dict.make()
  let results: dict<loadable<array<'a>>> = Dict.make()->Tilia.tilia

  // Which in-memory queries list this row. Whatever the store keeps beside
  // this walks its own dict: the linear-scan bet, applied twice.
  let joinEntries = value => {
    let vid = id(value)
    let joined = ref(false)
    entries->Dict.forEach(entry =>
      if matches(entry.query, value) {
        joined := true
        switch idsByKey->Dict.get(entry.key) {
        | Value(ids) if !(ids->Array.includes(vid)) =>
          // Do not mutate in place: the value may be shared.
          idsByKey->Dict.set(entry.key, ids->Array.concat([vid]))
        | _ => ()
        }
      } else {
        switch idsByKey->Dict.get(entry.key) {
        | Value(ids) if ids->Array.includes(vid) =>
          idsByKey->Dict.set(entry.key, ids->Array.filter(i => i !== vid))
        | _ => ()
        }
      }
    )
    joined.contents
  }

  // The one way B+C reaches A's rows.
  let binding = {
    item: rid =>
      switch itemById->Dict.get(rid) {
      | Value(value) => Some(value)
      | Null | Undefined => None
      },
    changed: values =>
      values->Array.forEach(value => {
        let vid = id(value)
        itemById->Dict.set(vid, value)
        if !joinEntries(value) {
          itemById->Dict.delete(vid)
        }
      }),
    removed: ids =>
      ids->Array.forEach(rid => {
        itemById->Dict.delete(rid)
        idsByKey->Dict.forEachWithKey((ids, key) =>
          if ids->Array.includes(rid) {
            idsByKey->Dict.set(key, ids->Array.filter(i => i !== rid))
          }
        )
      }),
    place: value => {
      itemById->Dict.set(id(value), value)
      joinEntries(value)->ignore
    },
  }

  // Tied here, and only here: the store is handed a binding that already
  // works, and hands back the source in the same breath. Neither half exists
  // unconnected, so no ordering rule can be got wrong — a store may use the
  // binding while its own constructor is still running.
  let (source, store) = connect(binding)

  // A · the answer becomes the query's result. Everything the store had to
  // do with these values it did before handing them over.
  let loaded = (entry, values, claim) => {
    if claim === Fresh {
      entry.refreshedAt = now()
    }
    values->Array.forEach(value => {
      itemById->Dict.set(id(value), value)
    })
    let ids = values->Array.map(id)
    idsByKey->Dict.set(entry.key, ids)
    // Rebuild when the id list or any listed item changes.
    let build = () => {
      let values = []
      switch idsByKey->Dict.get(entry.key) {
      | Value(ids) =>
        ids->Array.forEach(id =>
          switch itemById->Dict.get(id) {
          | Value(value) => values->Array.push(value)
          | Null | Undefined => ()
          }
        )
      | Null | Undefined => ()
      }
      // Observe sorting so edits to sort keys update the list.
      sort(entry.query)(values)
    }
    results->Dict.set(entry.key, Loaded({claim, data: Tilia.computed(build)}))
  }

  let fetch = makeFind(~schema, source, loaded, results, reportError)
  let getEntry = makeGetEntry(~schema, entry => fetch(entry), entries, results)

  let clearOnline = Tilia.watch(
    () => source.online.value,
    online => {
      if online {
        // Reconnect every query that does not still have a live source.
        entries->Dict.forEach(entry => fetch(entry))
      } else {
        entries->Dict.forEach(entry => {
          // Going offline frees the refresh slot for the next reconnect.
          entry.fetchedAt = 0.0
          switch getResult(results, entry) {
          | Loading => results->Dict.set(entry.key, NoData({reason: Offline}))
          | _ => ()
          }
        })
      }
    },
  )

  let tick = () => {
    let t = now()
    // Online refreshes get a buffer to avoid a brief local-freshness flip.
    let buffer = source.online.value ? expiry.refresh / 8.0 : 0.0
    let freshLimit = t - expiry.refresh - buffer
    let live = observedKeys(results)
    let online = source.online.value
    // Stamp live entries before expiry so only unobserved entries can drop.
    let dropped = []
    entries->Dict.forEach(entry => {
      if live->Set.has(entry.key) {
        entry.lastSeen = t
      }
      if t > entry.lastSeen + expiry.memory {
        dropped->Array.push(entry)
      } else {
        // Anything not fresh re-enters the refresh loop, whatever state
        // produced it: a local or partial answer, a stale remote one, or a
        // failure with nothing behind it. A live source owns its own recovery
        // instead (a later delivery or `end`), and an entry still waiting for
        // its first answer already has a find open.
        let stale = switch (entry.state, getResult(results, entry)) {
        | (LiveRemote, _) => false
        | (Pristine, Loading) => false
        | _ => true
        }
        if (
          stale &&
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
          | Loaded({data, claim: Fresh}) =>
            if entry.refreshedAt < freshLimit {
              results->Dict.set(entry.key, Loaded({data, claim: Local}))
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
        // The store stops maintaining what the engine no longer holds.
        source.forget(entry.query)
        let key = entry.key
        switch idsByKey->Dict.get(key) {
        | Value(ids) => ids->Array.forEach(id => orphans->Set.add(id))
        | Null | Undefined => ()
        }
        entries->Dict.delete(key)
        results->Dict.delete(key)
        idsByKey->Dict.delete(key)
      })
      idsByKey->Dict.forEach(ids => ids->Array.forEach(id => orphans->Set.delete(id)->ignore))
      orphans->Set.forEach(id => itemById->Dict.delete(id))
    }
    // The engine's half ran first: eviction has told the store what it no
    // longer has to maintain before the store sweeps.
    source.tick()
  }

  (
    {
      one: makeOne(getEntry, results, source.online),
      array: makeArray(getEntry, results, source.online),
      tick,
      dispose: () => {
        clearOnline()
        // Stop every still-open find. Cached values are left to normal expiry.
        entries->Dict.forEach(entry => entry.close())
        // The store last, so no find is in flight against a stopped store.
        // Neither half writes anything on the way out.
        source.dispose()
      },
      _canopy: () => {
        let {live, idle}: Tilia.canopy = Tilia._canopy(results)
        {live: live->Set.toArray, idle: idle->Set.toArray}
      },
    },
    store,
  )
}
