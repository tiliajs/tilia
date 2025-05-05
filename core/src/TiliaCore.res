module Reflect = {
  external has: ('a, string) => bool = "Reflect.has"
  external get: ('a, string) => 'b = "Reflect.get"
  external set: ('a, string, 'b) => bool = "Reflect.set"
  external deleteProperty: ('a, string) => bool = "Reflect.deleteProperty"
  external ownKeys: 'a => 'b = "Reflect.ownKeys"
}

module Exn = {
  @new external makeError: string => exn = "Error"
  let raiseError = str => raise(makeError(str))
}
module Proxy = {
  @new external make: ('a, 'b) => 'c = "Proxy"
}
module Typeof = {
  external array: 'a => bool = "Array.isArray"
  let object: 'a => bool = %raw(`
function(v) {
  return typeof v === 'object' && v !== null;
}
  `)
}

module Object = {
  type descriptor<'a> = {writable: bool, value: 'a}
  external hasOwn: ('a, string) => bool = "Object.hasOwn"
  external getOwnPropertyDescriptor: ('a, string) => nullable<descriptor<'b>> =
    "Object.getOwnPropertyDescriptor"
  let readonly: ('a, string) => bool = (o, k) => {
    switch getOwnPropertyDescriptor(o, k) {
    | Value(d) => d.writable === false
    | _ => false
    }
  }
}

module Dict = {
  type t<'a>
  @new external make: unit => t<'a> = "Map"
  @send external get: (t<'a>, string) => nullable<'a> = "get"
  @send external set: (t<'a>, string, 'b) => unit = "set"
  @send external delete: (t<'a>, string) => unit = "delete"
}

// This type is never used and only used to pass value.
type opaque

type dict<'a> = Dict.t<'a>
type compute = unit => unit

// Called when something changes in the index (added or removed keys)
let indexKey = %raw(`Symbol()`)
// Called on any change in the object or children (track method)
let trackKey = %raw(`Symbol()`)
// Used to get meta information (mostly for stats)
let metaKey = %raw(`Symbol()`)
// Used to compute values
let computeKey = %raw(`Symbol()`)

type state =
  | Pristine // Hasn't changed since value read.
  | Changed // Value changed and has been notified.
  | Cleared // No more observer registered: cleared.

type rec observer = {
  notify: unit => unit,
  clear: nullable<unit => unit>,
  // What this observer is observing (a list of watchers)
  observing: observing,
  // Where this observer is observing (not used anymore ?)
  root: root,
}
// Observed key => watchers
and observed = dict<watchers>
// Who to notify on change
and observers = Set.t<observer>
// Observers observing a given key in an object/array. We
// are mainly interested in the 'observers' set but we need
// the other attributes like state/key/observed to manage edge
// cases.
and watchers = {
  mutable state: state,
  // Tracked key in parent
  key: string,
  // Parent tracking
  observed: observed,
  // Set of observers to notify on change.
  observers: observers,
}
and root = {
  mutable observer: nullable<observer>,
  mutable triggers: nullable<Set.t<propagate>>,
  flush: (unit => unit) => unit,
}
// List of watchers to which the the observer should add itself on ready
and observing = array<watchers>

and propagate = {
  // Cannot use 'observed' because of the rec clause and
  // watchers having an 'observed' field already.
  obs: observed,
  ancestry: Set.t<propagate>,
}

type rec meta<'a> = {
  target: 'a,
  root: root,
  // The list of observers for each keys in the object. The trackKey triggers
  // on any change (including in children). The indexKey triggers on changes
  // to "index" (adding or removing children).
  observed: dict<watchers>,
  // Cached children proxy.
  proxied: dict<meta<'a>>,
  // Compute functions.
  computes: dict<compute>,
  // The observer and ancestry to propagate tracking.
  propagate: propagate,
  // The proxy itself (used by proxied).
  mutable proxy: 'a,
}

let _nmeta: 'a => nullable<meta<'a>> = p => Reflect.get(p, metaKey)
let _meta: 'a => meta<'a> = p => Reflect.get(p, metaKey)

let _connect = (p: 'a, notify) => {
  switch _nmeta(p) {
  | Value({root}) => {
      let observer: observer = {
        clear: Undefined,
        notify,
        observing: [],
        root,
      }
      root.observer = Value(observer)
      observer
    }
  | _ => Exn.raiseError("Observed state is not a tilia proxy.")
  }
}

let observeKey = (observed, key) => {
  switch Dict.get(observed, key) {
  | Value(w) => w
  | _ =>
    let w = {
      state: Pristine,
      key,
      observed,
      observers: Set.make(),
    }
    Dict.set(observed, key, w)
    w
  }
}

let _clear = (observer: observer) => {
  Array.forEach(observer.observing, watchers => {
    if (
      watchers.state == Pristine &&
      // No need to delete if state isn't Pristine
      Set.delete(watchers.observers, observer) &&
      Set.size(watchers.observers) === 0
    ) {
      // Cleanup
      watchers.state = Cleared
      Dict.delete(watchers.observed, watchers.key)
    }
  })
}

let clear = (observer: observer) => {
  _clear(observer)
  switch observer.clear {
  | Value(fn) => fn()
  | _ => ()
  }
}

let _ready = (observer: observer, ~notifyIfChanged: bool=true) => {
  let {root} = observer
  switch root.observer {
  | Value(o) if o === observer => root.observer = Undefined
  | _ => ()
  }
  ignore(
    Array.findWithIndex(observer.observing, (w, idx) => {
      switch w.state {
      | Pristine => {
          ignore(Set.add(w.observers, observer))
          false
        }
      | Changed if notifyIfChanged => {
          _clear(observer)
          observer.notify()
          true // abort loop
        }
      | _ => {
          let w = observeKey(w.observed, w.key)
          ignore(Set.add(w.observers, observer))
          observer.observing[idx] = w
          false
        }
      }
    }),
  )
}

let ownKeys = (root: root, observed: dict<watchers>, target: 'a): 'b => {
  let keys = Reflect.ownKeys(target)
  switch root.observer {
  | Value(o) => {
      let w = observeKey(observed, indexKey)
      Array.push(o.observing, w)
    }
  | _ => ()
  }
  keys
}

let rec collect = (accum: Set.t<observed>, ancestry: Set.t<propagate>) => {
  Set.forEach(ancestry, ({obs, ancestry}) => {
    if !Set.has(accum, obs) {
      Set.add(accum, obs)
      collect(accum, ancestry)
    }
  })
}

let flush = (triggers: Set.t<propagate>) => {
  let observers = Set.make()
  collect(observers, triggers)
  Set.forEach(observers, observed => {
    // Notify without reseting observer
    switch Dict.get(observed, trackKey) {
    | Value(watchers) => Set.forEach(watchers.observers, observer => observer.notify())
    | _ => ()
    }
  })
}

let notify = (observed, key) => {
  switch Dict.get(observed, key) {
  | Value(watchers) => {
      Dict.delete(observed, key)
      watchers.state = Changed
      Set.forEach(watchers.observers, observer => {
        _clear(observer)
        observer.notify()
      })
    }
  | _ => ()
  }
}

/* Something changed, notify. If there is already a set of triggers, we add to
 * it or create a new one. If creating a new one, we flush the triggers
 * synchronously or asynchronously depending on the flush function.
 */
let triggerTracking = (root, propagate) => {
  switch root.triggers {
  /* Existing trigger set (we are in an asynchronous flush mode). Add to it. */
  | Value(triggers) => Set.add(triggers, propagate)
  /* No trigger set: create one. */
  | _ => {
      let triggers = Set.make()
      Set.add(triggers, propagate)
      root.triggers = Value(triggers)
      root.flush(() => {
        root.triggers = Undefined
        flush(triggers)
      })
    }
  }
}

let deleteProxied = (proxied: dict<meta<'a>>, propagate: propagate, key: string) => {
  switch Dict.get(proxied, key) {
  | Value(m) =>
    // Child disconnected: will not trigger tracking anymore
    ignore(Set.delete(m.propagate.ancestry, propagate))
  | _ => ()
  }
  Dict.delete(proxied, key)
}

let set = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  propagate: propagate,
  target: 'a,
  key: string,
  value: 'b,
) => {
  let hadKey = Reflect.has(target, key)
  let prev = Reflect.get(target, key)
  if prev === value {
    true
  } else {
    switch Reflect.set(target, key, value) {
    | false => false
    | true =>
      if Typeof.object(prev) {
        deleteProxied(proxied, propagate, key)
      }
      notify(observed, key)
      if !hadKey {
        // new key: trigger index
        notify(observed, indexKey)
      }
      triggerTracking(root, propagate)
      true
    }
  }
}

let deleteProperty = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  propagate: propagate,
  target: 'a,
  key: string,
) => {
  let res = Reflect.deleteProperty(target, key)
  deleteProxied(proxied, propagate, key)
  notify(observed, key)
  triggerTracking(root, propagate)
  res
}

let rec get = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  computes: dict<compute>,
  propagate: propagate,
  meta: meta<'a>,
  isArray: bool,
  target: 'a,
  key: string,
): 'b => {
  if key === metaKey {
    // We use this to avoid argument removal by compilation (it is not
    // included in JS compiled code).
    ignore(meta)
    // We use raw to avoid type
    %raw(`meta`)
  } else {
    // is array and get length
    let v = Reflect.get(target, key)
    let own = Object.hasOwn(target, key)
    if v === undefined || own {
      switch root.observer {
      | Value(o) =>
        if isArray && key == "length" {
          let w = observeKey(observed, indexKey)
          Array.push(o.observing, w)
        } else {
          let w = observeKey(observed, key)
          Array.push(o.observing, w)
        }
      | _ => ()
      }

      let v = if v === computeKey {
        switch Dict.get(computes, key) {
        | Value(rebuild) => {
            rebuild()
            // The rebuild function always sets a value so we can get it now.
            Reflect.get(target, key)
          }
        | _ => Exn.raiseError("Compute function not found.")
        }
      } else {
        v
      }

      if Typeof.object(v) && !Object.readonly(target, key) {
        switch Dict.get(proxied, key) {
        | Value(m) => m.proxy
        | _ =>
          let m = proxify(root, propagate, v)
          Dict.set(proxied, key, m)
          m.proxy
        }
      } else {
        v
      }
    } else {
      v
    }
  }
}

and proxify = (root: root, parent_propagate: propagate, target: 'a): meta<'a> => {
  let proxied: dict<meta<'b>> = Dict.make()
  let observed: observed = Dict.make()
  let computes: dict<compute> = Dict.make()
  let ancestry = Set.make()

  // Register parent in child ancestry
  Set.add(ancestry, parent_propagate)

  // Create child propagation object
  let propagate: propagate = {obs: observed, ancestry}

  switch _nmeta(target) {
  | Value(m) if m.root === root => {
      /* same tree, reuse proxy */
      Set.add(m.propagate.ancestry, parent_propagate)
      m
    }
  | Value(m) => proxify(root, propagate, m.target) /* external tree: clear */
  | _ =>
    let meta: meta<'a> = %raw(`{root, target, observed, proxied, computes, propagate}`)
    let isArray = Typeof.array(target)
    let proxy = Proxy.make(
      target,
      {
        "set": set(root, observed, proxied, propagate, ...),
        "deleteProperty": deleteProperty(root, observed, proxied, propagate, ...),
        "get": get(root, observed, proxied, computes, propagate, meta, isArray, ...),
        "ownKeys": ownKeys(root, observed, ...),
      },
    )
    meta.proxy = proxy
    meta
  }
}

let timeOutFlush = (fn: unit => unit) => {
  ignore(setTimeout(() => fn(), 0))
}

let make = (seed: 'a, ~flush=timeOutFlush): 'a => {
  let root = {flush, observer: Undefined, triggers: Undefined}
  let propagate: propagate = {
    obs: Dict.make(),
    ancestry: Set.make(),
  }
  proxify(root, propagate, seed).proxy
}

let observe = (p: 'a, callback: 'a => unit) => {
  let rec notify = () => {
    let o = _connect(p, notify)
    callback(p)
    _ready(o, ~notifyIfChanged=false)
  }
  notify()
}

let track = (p: 'a, callback: 'a => unit) => {
  switch _nmeta(p) {
  | Value({root, observed}) => {
      let observer: observer = {
        clear: Undefined,
        notify: () => callback(p),
        observing: [],
        root,
      }
      let w = observeKey(observed, trackKey)
      ignore(Set.add(w.observers, observer))
      Array.push(observer.observing, w)
      observer
    }
  | _ => Exn.raiseError("Observed state is not a tilia proxy.")
  }
}

type clear_o = {mutable o: nullable<observer>}
type lastValue = {mutable v: opaque}

let compute = (p: 'a, key: string, callback: 'a => unit) => {
  switch _nmeta(p) {
  | Value({root, target, computes}) => {
      let v = Reflect.get(target, key)
      let lastValue: lastValue = {v: v}
      let clearCache = () => {
        let v = Reflect.get(target, key)
        if v !== computeKey {
          lastValue.v = v
        }
        // Now cache is hidden behind the computeKey.
        ignore(Reflect.set(target, key, computeKey))
      }
      let clear_o = {o: Undefined}
      let rebuild = () => {
        // Make sure any further read gets the last value until we
        // are done with rebuilding the value.
        Console.log(lastValue.v)
        ignore(Reflect.set(target, key, lastValue.v))
        // On change: hide cache.
        let o = _connect(p, clearCache)
        clear_o.o = Value(o)
        // Rebuild value (will only retrigger on next read after
        // cache clear).
        callback(p)
        _ready(o, ~notifyIfChanged=false)
      }
      Dict.set(computes, key, rebuild)
      ignore(Reflect.set(target, key, computeKey))

      // Compute clearing function
      let clear = () => {
        // Clear our cache clearing observer
        switch clear_o.o {
        | Value(o) => _clear(o)
        | _ => ()
        }

        // Only remove our rebuild function
        switch Dict.get(computes, key) {
        | Value(c) if c === rebuild => {
            Dict.delete(computes, key)
            if Reflect.get(target, key) === computeKey {
              ignore(Reflect.set(target, key, lastValue.v))
            }
          }
        | _ => ()
        }
      }
      let observer = {
        notify: () => (),
        clear: Value(clear),
        observing: [],
        root,
      }
      observer
    }
  | _ => Exn.raiseError("Observed state is not a tilia proxy.")
  }
}
