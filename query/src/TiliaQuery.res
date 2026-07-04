@tag("state")
type loadable<'a> =
  | @as("loading") Loading
  | @as("loaded") Loaded({data: 'a})
  | @as("notFound") NotFound

module Channel = {
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

@send external insertAt: (array<'a>, int, int, 'a) => array<'a> = "splice"
@send external removeAt: (array<'a>, int, int) => array<'a> = "splice"

module Dict = {
  type t<'a>
  let make: unit => t<'a> = %raw(`() => ({})`)
  @val @scope("Reflect") external get: (t<'a>, string) => nullable<'a> = "get"
  @val @scope("Reflect") external getKnown: (t<'a>, string) => 'a = "get"
  @val @scope("Reflect") external set: (t<'a>, string, 'a) => unit = "set"
  @val @scope("Reflect") external delete: (t<'a>, string) => unit = "deleteProperty"
  @val @scope("Object") external keys: t<'a> => array<string> = "keys"
}

type dict<'a>

module Object = {
  @val @scope("Reflect") external get: (dict<'a>, string) => nullable<'a> = "get"
  @val @scope("Object") external fromEntries: array<(string, 'a)> => dict<'a> = "fromEntries"
}

module Json = {
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
  matches?: ('query, 'a) => bool,
  sort?: ('a, 'a) => float,
}

type meta<'query> = {
  filter: 'query,
  mutable fetched: float,
  mutable idle: option<float>,
  // Raw id list of the last emitted result: same target as the loadable's
  // data array, safe to read from tracked scopes (fetch channel callbacks).
  mutable ids: option<array<string>>,
}

let makeFetchChannel = (~emit, ~fail, ~covered): (Channel.fetch<'a>, unit => unit) => {
  open Channel
  let (state, setState) = Tilia.signal(Live)
  let guard = (run, value) =>
    switch state.value {
    | Live => run(value)
    | Cancelled => ()
    }
  let channel = Tilia.tilia({
    state: Tilia.lift(state),
    emit: rows => guard(emit, rows),
    fail: message => guard(fail, message),
    covered: () => guard(covered, ()),
  })
  (channel, () => setState(Cancelled))
}

let makeWriteChannel = (~emit, ~offline, ~conflict, ~reject): (Channel.write<'a>, unit => unit) => {
  open Channel
  let (state, setState) = Tilia.signal(Live)
  let guard = (run, value) =>
    switch state.value {
    | Live => run(value)
    | Cancelled => ()
    }
  let channel = Tilia.tilia({
    state: Tilia.lift(state),
    emit: value => guard(emit, value),
    offline: () => guard(offline, ()),
    conflict: server => guard(conflict, server),
    reject: message => guard(reject, message),
  })
  (channel, () => setState(Cancelled))
}

module Outbox = {
  type entry<'a> = {
    write: write<'a>,
    // None = queued, Some(f) = in flight, f cancels the channel
    mutable cancel: option<unit => unit>,
  }

  type entries<'a> = Dict.t<entry<'a>>
  type t<'a> = {
    send: write<'a> => unit,
    replay: unit => unit,
    cancel: unit => unit,
    clear: unit => unit,
    pending: string => bool,
    deleting: string => bool,
  }

  let make = (
    ~id: 'a => string,
    ~remote: remote<'a, 'query>,
    ~local: store<'a, 'query>,
    ~resolve: 'a => 'a,
    ~evict: 'a => 'a,
    ~stale: unit => unit,
    ~status: status<'a>,
  ) => {
    let entries: entries<'a> = Dict.make()

    let track = () => status.pending = Dict.keys(entries)->Array.length

    let pending = itemId =>
      switch Dict.get(entries, itemId) {
      | Value(_) => true
      | _ => false
      }

    let deleting = itemId =>
      switch Dict.get(entries, itemId) {
      | Value(entry) => entry.write.deleted
      | _ => false
      }

    let stop = (entry: entry<'a>) =>
      switch entry.cancel {
      | Some(cancel) => {
          cancel()
          entry.cancel = None
        }
      | None => ()
      }

    let remove = (itemId, entry) =>
      switch Dict.get(entries, itemId) {
      | Value(current) if current === entry => {
          stop(current)
          Dict.delete(entries, itemId)
          track()
          true
        }
      | _ => false
      }

    let cancel = () =>
      Dict.keys(entries)->Array.forEach(itemId =>
        switch Dict.get(entries, itemId) {
        | Value(entry) => stop(entry)
        | _ => ()
        }
      )

    let clear = () => {
      cancel()
      Dict.keys(entries)->Array.forEach(itemId => Dict.delete(entries, itemId))
      track()
    }

    let dispatch = (itemId, entry: entry<'a>) => {
      let value = entry.write.value
      // Keep the entry queued and dirty for the next reconnect.
      let offline = () =>
        switch Dict.get(entries, itemId) {
        | Value(current) if current === entry => stop(current)
        | _ => ()
        }
      if entry.write.deleted {
        let settle = _confirmed =>
          if remove(itemId, entry) {
            local.remove(value, false)
            ignore(evict(value))
          }
        // Server resurrects the row on conflict.
        let conflict = server =>
          if remove(itemId, entry) {
            local.save(server, false)
            ignore(resolve(server))
          }
        let reject = message =>
          if remove(itemId, entry) {
            // Delete rejected: keep the row clean locally and in cache, then
            // refetch to converge if the server row changed meanwhile.
            local.save(value, false)
            ignore(resolve(value))
            status.rejected = [...status.rejected, {value, deleted: true, message}]
            stale()
          }
        let (channel, cancelChannel) = makeWriteChannel(~emit=settle, ~offline, ~conflict, ~reject)
        entry.cancel = Some(cancelChannel)
        remote.remove(value, channel)
      } else {
        let settle = saved =>
          if remove(itemId, entry) {
            local.save(saved, false)
            ignore(resolve(saved))
          }
        let reject = message =>
          if remove(itemId, entry) {
            // Stop retries; the stale refetch restores server truth.
            local.save(value, false)
            status.rejected = [...status.rejected, {value, deleted: false, message}]
            stale()
          }
        let (channel, cancelChannel) = makeWriteChannel(
          ~emit=settle,
          ~offline,
          ~conflict=settle,
          ~reject,
        )
        entry.cancel = Some(cancelChannel)
        remote.upsert(value, channel)
      }
    }

    let replay = () =>
      if remote.online {
        Dict.keys(entries)->Array.forEach(itemId =>
          switch Dict.get(entries, itemId) {
          | Value(entry) =>
            switch entry.cancel {
            | None => dispatch(itemId, entry)
            | Some(_) => ()
            }
          | _ => ()
          }
        )
      }

    let send = (w: write<'a>) => {
      let itemId = id(w.value)
      switch Dict.get(entries, itemId) {
      | Value(entry) => stop(entry)
      | _ => ()
      }
      Dict.set(entries, itemId, {write: w, cancel: None})
      track()
      if w.deleted {
        local.remove(w.value, true)
        ignore(evict(w.value))
      } else {
        local.save(w.value, true)
        ignore(resolve(w.value))
      }
      if remote.online {
        replay()
      }
    }

    {send, replay, cancel, clear, pending, deleting}
  }
}

let defaultNow = () => Date.now() /. 1000.0

let make = (config: config<'a, 'query>) => {
  let {id, remote} = config
  let local: store<_, _> = switch config.local {
  | Some(local) => local
  | None => {
      fetch: (_, _) => None,
      save: (_, _) => (),
      remove: (_, _) => (),
      dirty: () => Promise.resolve([]),
    }
  }
  let stale = config.stale->Option.getOr(30.0)
  let gc = config.gc->Option.getOr(300.0)
  let now = config.now->Option.getOr(defaultNow)
  let key = config.key->Option.getOr(Json.sortedStringify)
  let matches = config.matches
  let sort = config.sort
  let cache: Dict.t<'a> = Dict.make()->Tilia.tilia
  let queries: Dict.t<loadable<array<string>>> = Dict.make()->Tilia.tilia
  let ones: Dict.t<loadable<'a>> = Dict.make()->Tilia.tilia
  let arrays: Dict.t<loadable<array<'a>>> = Dict.make()->Tilia.tilia
  let dicts: Dict.t<loadable<dict<'a>>> = Dict.make()->Tilia.tilia
  let meta: Dict.t<meta<'query>> = Dict.make()
  let staleKeys: Dict.t<bool> = Dict.make()->Tilia.tilia
  let fetchCancels: Dict.t<unit => unit> = Dict.make()

  let stopFetch = cacheKey =>
    switch Dict.get(fetchCancels, cacheKey) {
    | Value(cancel) => {
        cancel()
        Dict.delete(fetchCancels, cacheKey)
      }
    | _ => ()
    }

  // A rejected write leaves server truth unknown (the object may belong to
  // lists it optimistically left), so every query refetches to converge.
  let converge = () => Dict.keys(meta)->Array.forEach(cacheKey => Dict.set(staleKeys, cacheKey, true))

  // Sorted insertion position: first cached row that sorts after the item.
  let position = (ids: array<string>, item) =>
    switch sort {
    | Some(cmp) =>
      ids->Array.findIndex(otherId =>
        switch Dict.get(cache, otherId) {
        | Value(other) => cmp(other, item) > 0.0
        | _ => false
        }
      )
    | None => -1
    }

  let same = (a, b) =>
    Array.length(a) == Array.length(b) && a->Array.everyWithIndex((v, i) => b->Array.getUnsafe(i) === v)

  // Commit a next id-list only when membership changed. The list is stored
  // both in query metadata (raw) and in the reactive query state.
  let commit = (cacheKey, m, ids) =>
    switch m.ids {
    | Some(prev) if same(prev, ids) => ()
    | _ => {
        m.ids = Some(ids)
        Dict.set(queries, cacheKey, Loaded({data: ids}))
      }
    }

  // The changed object is known, so query id-lists are updated in place
  // (no stale marking, no fetch): the id enters lists whose filter matches
  // and leaves lists that contain it but no longer match.
  let apply = item =>
    switch matches {
    | None => ()
    | Some(matches) => {
        let itemId = id(item)
        Dict.keys(meta)->Array.forEach(cacheKey =>
          switch Dict.get(meta, cacheKey) {
          | Value(m) =>
            switch m.ids {
            | Some(ids) => {
              let index = ids->Array.indexOf(itemId)
              if matches(m.filter, item) {
                if index < 0 {
                  let next = [...ids]
                  let at = position(ids, item)
                  if at < 0 {
                    next->Array.push(itemId)
                  } else {
                    ignore(insertAt(next, at, 0, itemId))
                  }
                  commit(cacheKey, m, next)
                }
              } else if index >= 0 {
                let next = [...ids]
                ignore(removeAt(next, index, 1))
                commit(cacheKey, m, next)
              }
            }
            | None => ()
            }
          | _ => ()
          }
        )
      }
    }

  // A deleted object leaves every list that contains it.
  let drop = itemId =>
    Dict.keys(meta)->Array.forEach(cacheKey =>
      switch Dict.get(meta, cacheKey) {
      | Value(m) =>
        switch m.ids {
        | Some(ids) => {
          let index = ids->Array.indexOf(itemId)
          if index >= 0 {
            let next = [...ids]
            ignore(removeAt(next, index, 1))
            commit(cacheKey, m, next)
          }
        }
        | None => ()
        }
      | _ => ()
      }
    )

  let resolve = item => {
    Dict.set(cache, id(item), item)
    apply(item)
    item
  }

  let evict = item => {
    Dict.delete(cache, id(item))
    drop(id(item))
    item
  }

  let status: status<'a> = Tilia.tilia({pending: 0, rejected: [], error: None})

  let writes = Outbox.make(~id, ~remote, ~local, ~resolve, ~evict, ~stale=converge, ~status)

  let startFetch = (cacheKey, filter, set) => {
    stopFetch(cacheKey)
    let fresh = () => {
      status.error = None
      switch Dict.get(meta, cacheKey) {
      | Value(m) => m.fetched = now()
      | _ => ()
      }
    }
    // Remote rows are authoritative: they refresh freshness and write through
    // to the local store. Rows with a pending upsert keep their optimistic value;
    // rows with a pending delete are dropped so a fetch cannot resurrect them.
    let receive = (authority, list) => {
      let rows = switch sort {
      | Some(cmp) => list->Array.toSorted(cmp)
      | None => list
      }
      let ids = rows->Array.filterMap(item => {
        let itemId = id(item)
        if writes.deleting(itemId) {
          None
        } else {
          if !writes.pending(itemId) {
            Dict.set(cache, itemId, item)
            if authority {
              local.save(item, false)
            }
          }
          Some(itemId)
        }
      })
      // An unchanged id-list keeps the current loadable and views untouched.
      // `meta.ids` shares its target with the loadable's data array (in-place
      // membership edits stay in sync), and is safe to read here: this can run
      // inside the loader's tracked scope, where reading `queries` would
      // subscribe the loader to its own result.
      switch Dict.get(meta, cacheKey) {
      | Value({ids: Some(prev)}) if same(prev, ids) => ()
      | Value(m) => {
          m.ids = Some(ids)
          set(Loaded({data: ids}))
        }
      | _ => set(Loaded({data: ids}))
      }
      if authority {
        fresh()
      }
    }
    let tier = (fetch, authority, fail) => {
      let (channel, cancelChannel) = makeFetchChannel(
        ~emit=rows => receive(authority, rows),
        ~fail,
        ~covered=() => fresh(),
      )
      let cleanup = switch fetch(filter, channel) {
      | Some(cleanup) => cleanup
      | None => () => ()
      }
      () => {
        cancelChannel()
        cleanup()
      }
    }
    let cancelLocal = tier(local.fetch, false, _ => ())
    // A remote failure leaves freshness untouched (retried on the next stale
    // window) and is surfaced on status.
    let cancelRemote = remote.online
      ? tier(remote.fetch, true, message => status.error = Some({key: cacheKey, message}))
      : () => ()
    Dict.set(fetchCancels, cacheKey, () => {
      cancelLocal()
      cancelRemote()
    })
    Dict.delete(staleKeys, cacheKey)
  }

  let loader = (cacheKey, filter) =>
    (_prev, set) =>
      switch Dict.get(staleKeys, cacheKey) {
      | Undefined => ()
      | _ => startFetch(cacheKey, filter, set)
      }

  let replay = () => {
    let canopy = Tilia._canopy(queries)
    Set.forEach(canopy.live, cacheKey => Dict.set(staleKeys, cacheKey, true))
    writes.replay()
  }

  // Connectivity watcher, hand-rolled on the observer API so dispose() can
  // stop it (Tilia.watch returns no handle).
  let online = ref(remote.online)
  let disposed = ref(false)
  let watcher: ref<option<Tilia.observer>> = ref(None)

  let rec connectivity = () =>
    if !disposed.contents {
      let o = Tilia._observe(connectivity)
      let live = remote.online
      Tilia._done(o)
      watcher := Some(o)
      let prev = online.contents
      online := live
      if !prev && live {
        Tilia.batch(replay)
      } else if prev && !live {
        Tilia.batch(writes.cancel)
      }
      Tilia._ready(o, false)
    }
  connectivity()

  let get = id =>
    switch Dict.get(cache, id) {
    | Value(item) => Loaded({data: item})
    | _ => NotFound
    }

  let query = filter => {
    let cacheKey = key(filter)
    switch Dict.get(queries, cacheKey) {
    | Value(q) => q
    | _ => {
        Dict.set(meta, cacheKey, {filter, fetched: 0.0, idle: None, ids: None})
        Dict.set(staleKeys, cacheKey, true)
        let s = Tilia.source(Loading, loader(cacheKey, filter))
        Dict.set(queries, cacheKey, s)
        Dict.getKnown(queries, cacheKey)
      }
    }
  }

  // Detail view: same two-tier fetch as any query, resolving the first row.
  // NotFound when the query answered with an empty result.
  let one = filter => {
    let cacheKey = key(filter)
    ignore(query(filter))
    switch Dict.get(ones, cacheKey) {
    | Value(view) => view
    | _ => {
        Dict.set(
          ones,
          cacheKey,
          Tilia.computed(() =>
            switch Dict.getKnown(queries, cacheKey) {
            | Loading => Loading
            | NotFound => NotFound
            | Loaded({data: ids}) =>
              switch ids[0] {
              | Some(id) => Loaded({data: Dict.getKnown(cache, id)})
              | None => NotFound
              }
            }
          ),
        )
        Dict.getKnown(ones, cacheKey)
      }
    }
  }

  // Views are memoized per query key so repeated reads return the same proxy;
  // the computed rebuilds only when the query's id list changes.
  let array = filter => {
    let cacheKey = key(filter)
    ignore(query(filter))
    switch Dict.get(arrays, cacheKey) {
    | Value(view) => view
    | _ => {
        Dict.set(
          arrays,
          cacheKey,
          Tilia.computed(() =>
            switch Dict.getKnown(queries, cacheKey) {
            | Loading => Loading
            | NotFound => NotFound
            | Loaded({data: ids}) =>
              Loaded({
                data: ids
                ->Array.map(id => Tilia.computed(() => Dict.getKnown(cache, id)))
                ->Tilia.tilia,
              })
            }
          ),
        )
        Dict.getKnown(arrays, cacheKey)
      }
    }
  }

  let dict = filter => {
    let cacheKey = key(filter)
    ignore(query(filter))
    switch Dict.get(dicts, cacheKey) {
    | Value(view) => view
    | _ => {
        Dict.set(
          dicts,
          cacheKey,
          Tilia.computed(() =>
            switch Dict.getKnown(queries, cacheKey) {
            | Loading => Loading
            | NotFound => NotFound
            | Loaded({data: ids}) =>
              Loaded({
                data: ids
                ->Array.map(id => (id, Tilia.computed(() => Dict.getKnown(cache, id))))
                ->Object.fromEntries
                ->Tilia.tilia,
              })
            }
          ),
        )
        Dict.getKnown(dicts, cacheKey)
      }
    }
  }

  let sync = item => ignore(resolve(item))

  let upsert = item => writes.send({value: item, deleted: false})

  let remove = item => writes.send({value: item, deleted: true})

  let tick = () => {
    let current = now()
    let canopy = Tilia._canopy(queries)
    Set.forEach(canopy.live, k =>
      switch Dict.get(meta, k) {
      | Value(m) => {
          m.idle = None
          if remote.online && current -. m.fetched >= stale {
            Dict.set(staleKeys, k, true)
          }
        }
      | _ => ()
      }
    )
    let evicted = ref(false)
    Set.forEach(canopy.idle, k =>
      switch Dict.get(meta, k) {
      | Value(m) =>
        switch m.idle {
        | None => m.idle = Some(current)
        | Some(t) if current -. t >= gc => {
            stopFetch(k)
            Dict.delete(ones, k)
            Dict.delete(arrays, k)
            Dict.delete(dicts, k)
            Dict.delete(queries, k)
            Dict.delete(meta, k)
            Dict.delete(staleKeys, k)
            evicted := true
          }
        | Some(_) => ()
        }
      | _ => ()
      }
    )
    if evicted.contents {
      let referenced = Set.make()
      Dict.keys(queries)->Array.forEach(k =>
        switch Dict.getKnown(queries, k) {
        | Loaded({data: ids}) => ids->Array.forEach(id => Set.add(referenced, id))
        | _ => ()
        }
      )
      Dict.keys(cache)->Array.forEach(id =>
        if !Set.has(referenced, id) {
          Dict.delete(cache, id)
        }
      )
    }
  }

  let dismiss = () => status.rejected = []

  // Stop the connectivity watcher and cancel every open channel; the instance
  // stays readable but inert.
  let dispose = () =>
    if !disposed.contents {
      disposed := true
      switch watcher.contents {
      // `_done` detaches the manual observer without pruning computed trees.
      // This avoids dispose-time crashes when dependencies were rebuilt.
      | Some(o) => Tilia._done(o)
      | None => ()
      }
      Dict.keys(fetchCancels)->Array.forEach(stopFetch)
      writes.cancel()
    }

  // Empty memory state and the outbox (logout / user switch). The local
  // database is not touched: wiping it is the adapter's job.
  let clear = () => {
    writes.clear()
    Dict.keys(fetchCancels)->Array.forEach(stopFetch)
    Dict.keys(queries)->Array.forEach(k => Dict.delete(queries, k))
    Dict.keys(ones)->Array.forEach(k => Dict.delete(ones, k))
    Dict.keys(arrays)->Array.forEach(k => Dict.delete(arrays, k))
    Dict.keys(dicts)->Array.forEach(k => Dict.delete(dicts, k))
    Dict.keys(meta)->Array.forEach(k => Dict.delete(meta, k))
    Dict.keys(staleKeys)->Array.forEach(k => Dict.delete(staleKeys, k))
    Dict.keys(cache)->Array.forEach(k => Dict.delete(cache, k))
    status.rejected = []
    status.error = None
  }

  // Boot: queue pending writes from the previous session; replay happens
  // through the normal online flow.
  local.dirty()
  ->Promise.thenResolve(rows =>
    if !disposed.contents {
      rows->Array.forEach(writes.send)
    }
  )
  ->ignore

  {get, one, array, dict, upsert, remove, sync, tick, status, dismiss, dispose, clear}
}
