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

// Called when something changes in the index (added or removed keys)
let indexKey = %raw(`Symbol()`)
// Called on any change in the object or children (track method)
let trackKey = %raw(`Symbol()`)
// Used to get meta information (mostly for stats)
let metaKey = %raw(`Symbol()`)
// Mark a function as being a compute value
let computeKey = %raw(`Symbol()`)

// This is also used to detect compute in init state (they have a noop clear
// function).
let noop = () => ()

// This type is never used and only used to pass value.
type opaque
type rootp

type compute<'p, 'a> = {
  initValue: 'a,
  mutable clear: unit => unit,
  mutable rebuild: 'p => 'a,
}

module Typeof = {
  external array: 'a => bool = "Array.isArray"
  let object: 'a => bool = %raw(`
function(v) {
  return typeof v === 'object' && v !== null;
}
  `)

  let compute: 'a => nullable<compute<rootp, 'a>> = %raw(`
function(v) {
  return typeof v === 'object' && v !== null && v[computeKey] ? v : undefined;
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
  @send external has: (t<'a>, string) => bool = "has"
  @send external set: (t<'a>, string, 'b) => unit = "set"
  @send external delete: (t<'a>, string) => unit = "delete"
}

type dict<'a> = Dict.t<'a>

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
  mutable proxy: rootp,
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
  computes: dict<compute<rootp, opaque>>,
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
  | _ => {
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

type observerRef = {mutable o: nullable<observer>}
type lastValue<'a> = {mutable v: 'a}

let rec set = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  computes: dict<compute<rootp, opaque>>,
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
      switch Typeof.compute(value) {
      | Value(compute) =>
        // New computed value (install it and only notify is needed)
        switch Dict.get(computes, key) {
        | Value({clear}) => {
            // Updating the compute function: clear old one.
            clear()
            Dict.delete(computes, key)
          }
        | _ => ()
        }
        setupComputed(root, observed, proxied, computes, propagate, target, key, compute)
        if Dict.has(observed, key) {
          // Computed value is already observed: notify
          set(
            root,
            observed,
            proxied,
            computes,
            propagate,
            target,
            key,
            compute.rebuild(root.proxy),
          )
        } else {
          true
        }
      | _ => {
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
  }
}

and setupComputed = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  computes: dict<compute<rootp, opaque>>,
  propagate: propagate,
  target: 'a,
  key: string,
  compute: compute<rootp, 'b>,
) => {
  let p = root.proxy
  let lastValue: lastValue<'b> = {v: compute.initValue}
  let observer = {o: Undefined}
  // Initial compute has raw callback as rebuild method
  let callback = compute.rebuild

  let rec notify = () => {
    let v = Reflect.get(target, key)
    if v !== compute {
      lastValue.v = v
    }
    if Dict.has(observed, key) {
      // We have observers on this key: rebuild() and if the key changed, it
      // will notify cache observers.
      ignore(set(root, observed, proxied, computes, propagate, target, key, rebuild(p)))
    } else {
      // We do not have observers: reset value.
      // Make sure the previous proxy (if any) is removed so that it is not
      // served in place of triggering the compute.
      ignore(Reflect.deleteProperty(proxied, key))
      ignore(Reflect.set(target, key, compute))
    }
  }
  and rebuild = p => {
    // Make sure any further read gets the last value until we
    // are done with rebuilding the value. This is also useful if the
    // callback needs the previous value and to detect unchanged value.
    ignore(Reflect.set(target, key, lastValue.v))
    let o: observer = {
      clear: Undefined,
      notify,
      observing: [],
      root,
    }
    observer.o = Value(o)

    let previous = root.observer
    root.observer = Value(o)
    let v = callback(p)
    _ready(o, ~notifyIfChanged=false)
    root.observer = previous

    v
  }
  compute.rebuild = rebuild

  compute.clear = () => {
    // Clear our cache clearing observer
    switch observer.o {
    | Value(o) => _clear(o)
    | _ => ()
    }
  }
  Dict.set(computes, key, compute)
}

let deleteProperty = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  computes: dict<compute<rootp, opaque>>,
  propagate: propagate,
  target: 'a,
  key: string,
) => {
  let res = Reflect.deleteProperty(target, key)
  deleteProxied(proxied, propagate, key)
  switch Dict.get(computes, key) {
  | Value({clear}) => {
      clear()
      Dict.delete(computes, key)
    }
  | _ => ()
  }
  notify(observed, key)
  triggerTracking(root, propagate)
  res
}

let rec get = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  computes: dict<compute<rootp, opaque>>,
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

      if Typeof.object(v) && !Object.readonly(target, key) {
        switch Typeof.compute(v) {
        | Value(compute) if compute.clear === noop =>
          // New compute: need setup
          setupComputed(root, observed, proxied, computes, propagate, target, key, compute)
          let v = compute.rebuild(root.proxy)
          ignore(Reflect.set(target, key, v))
          if Typeof.object(v) && !Object.readonly(target, key) {
            let m = proxify(root, propagate, v)
            Dict.set(proxied, key, m)
            m.proxy
          } else {
            v
          }
        | Value(compute) => compute.rebuild(root.proxy)
        | _ =>
          switch Dict.get(proxied, key) {
          | Value(m) => m.proxy
          | _ =>
            let m = proxify(root, propagate, v)
            Dict.set(proxied, key, m)
            m.proxy
          }
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
  let computes: dict<compute<rootp, opaque>> = Dict.make()
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
        "set": set(root, observed, proxied, computes, propagate, ...),
        "deleteProperty": deleteProperty(root, observed, proxied, computes, propagate, ...),
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
  let root = {flush, observer: Undefined, triggers: Undefined, proxy: %raw(`seed`)}
  let propagate: propagate = {
    obs: Dict.make(),
    ancestry: Set.make(),
  }

  // FIXME
  let p = proxify(root, propagate, seed).proxy
  root.proxy = %raw(`p`)
  p
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

type computed<'p, 'a> = ('a, 'p => 'a) => 'a

let computed = (initValue: 'a, callback: 'p => 'a) => {
  let v = {clear: noop, rebuild: callback, initValue}
  ignore(Reflect.set(v, computeKey, true))
  %raw(`v`)
}
