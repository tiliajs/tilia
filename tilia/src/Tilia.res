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
// Used to get meta information (mostly for stats)
let metaKey = %raw(`Symbol()`)
// Mark a function as being a compute value
let computeKey = %raw(`Symbol()`)

// This is also used to detect compute in init state (they have a noop clear
// function).
let noop = () => ()

// This type is never used and only used to pass value.
type opaque
type branchp
type base = {mutable proxy: branchp}

type compute<'p, 'a> = {
  mutable clear: unit => unit,
  mutable rebuild: 'p => 'a,
}

module Typeof = {
  external array: 'a => bool = "Array.isArray"

  let proxiable: 'a => bool = %raw(`
function(v) {
  if ( typeof v === 'object' && v !== null) {
    const proto = Object.getPrototypeOf(v)
    return proto === Object.prototype || proto === Array.prototype || proto === null
  }
  return false;
}
  `)

  let compute: 'a => nullable<compute<branchp, 'a>> = %raw(`
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
  // What this observer is observing (a list of watchers)
  observing: observing,
  // Reference to the root is needed for ready call.
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
  // List of watchers to clear on next flush
  // Should rename 'triggers' to 'expired'.
  mutable expired: nullable<Set.t<observer>>,
  flush: (unit => unit) => unit,
}

// List of watchers to which the the observer should add itself on ready
and observing = array<watchers>

type tilia<'a> = {
  /** Create a new tilia proxy and connect it to the forest.
   */
  connect: 'a. 'a => 'a,
  /** Re-runs a callback whenever any of the observed values changes. 
  * The observer implements a PUSH model (changes "push" the callback to run).
  *
  * See "computed" for a PULL model where the callback is only called when the
  * produced value is read.
  */
  observe: (unit => unit) => unit,
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
  computes: dict<compute<branchp, opaque>>,
  // The proxy itself (used by proxied).
  mutable proxy: 'a,
}

let _nmeta: 'a => nullable<meta<'a>> = p => Reflect.get(p, metaKey)
let _meta: 'a => meta<'a> = p => Reflect.get(p, metaKey)

@inline
let _setObserver = (root, notify) => {
  let observer: observer = {
    notify,
    observing: [],
    root,
  }
  root.observer = Value(observer)
  observer
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

let notify = (root, observed, key) => {
  switch Dict.get(observed, key) {
  | Value(watchers) => {
      // No need to remember this observed key
      Dict.delete(observed, key)
      watchers.state = Changed

      // Notify
      switch root.expired {
      | Value(expired) =>
        Set.forEach(watchers.observers, observer => {
          _clear(observer)
          Set.add(expired, observer)
        })
      | _ => {
          // No expired set: create one.
          let expired = Set.make()
          Set.forEach(watchers.observers, observer => {
            _clear(observer)
            Set.add(expired, observer)
          })
          root.expired = Value(expired)
          root.flush(() => {
            root.expired = Undefined
            Set.forEach(expired, observer => observer.notify())
          })
        }
      }
    }
  | _ => ()
  }
}

type observerRef = {mutable o: nullable<observer>}
type lastValue<'a> = {mutable v: 'a}

let rec set = (
  root: root,
  base: base,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  computes: dict<compute<branchp, opaque>>,
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
      if Typeof.proxiable(prev) {
        Dict.delete(proxied, key)
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
        setupComputed(root, base, observed, proxied, computes, target, key, compute)
        if Dict.has(observed, key) {
          // Computed value is observed: notify
          set(root, base, observed, proxied, computes, target, key, compute.rebuild(base.proxy))
        } else {
          true
        }
      | _ => {
          notify(root, observed, key)
          if !hadKey {
            // new key: trigger index
            notify(root, observed, indexKey)
          }
          true
        }
      }
    }
  }
}

and setupComputed = (
  root: root,
  base: base,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  computes: dict<compute<branchp, opaque>>,
  target: 'a,
  key: string,
  compute: compute<branchp, 'b>,
) => {
  let lastValue: lastValue<'b> = {v: %raw(`undefined`)}
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
      ignore(set(root, base, observed, proxied, computes, target, key, rebuild(base.proxy)))
    } else {
      // We do not have observers: reset value.
      // Make sure the previous proxy (if any) is removed so that it is not
      // served in place of triggering the compute.
      ignore(Reflect.deleteProperty(proxied, key))
      ignore(Reflect.set(target, key, compute))
    }
  }
  and rebuild = p => {
    // Make sure any further read gets the last value until we are done with
    // rebuilding the value. This is also useful if the callback needs the
    // previous value and to detect unchanged value.  If possible, the callback
    // should avoid accessing this value because it can be undefined on first
    // run and breaks typing.
    ignore(Reflect.set(target, key, lastValue.v))
    let o: observer = {
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
  computes: dict<compute<branchp, opaque>>,
  target: 'a,
  key: string,
) => {
  let res = Reflect.deleteProperty(target, key)
  Dict.delete(proxied, key)
  switch Dict.get(computes, key) {
  | Value({clear}) => {
      clear()
      Dict.delete(computes, key)
    }
  | _ => ()
  }
  notify(root, observed, key)
  res
}

let rec get = (
  root: root,
  base: base,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  computes: dict<compute<branchp, opaque>>,
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

      if Typeof.proxiable(v) && !Object.readonly(target, key) {
        switch Typeof.compute(v) {
        | Value(compute) => {
            if compute.clear === noop {
              // New compute: need setup
              setupComputed(root, base, observed, proxied, computes, target, key, compute)
            }
            let v = compute.rebuild(base.proxy)
            ignore(Reflect.set(target, key, v))
            if Typeof.proxiable(v) && !Object.readonly(target, key) {
              let m = proxify(root, base, v)
              Dict.set(proxied, key, m)
              m.proxy
            } else {
              v
            }
          }
        | _ =>
          switch Dict.get(proxied, key) {
          | Value(m) => m.proxy
          | _ =>
            let m = proxify(root, base, v)
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

and proxify = (root: root, base: base, target: 'a): meta<'a> => {
  let proxied: dict<meta<'b>> = Dict.make()
  let observed: observed = Dict.make()
  let computes: dict<compute<branchp, opaque>> = Dict.make()

  switch _nmeta(target) {
  | Value(m) if m.root === root => /* same tree, reuse proxy */
    m
  | Value(m) => proxify(root, base, m.target) /* external tree: clear */
  | _ =>
    let meta: meta<'a> = %raw(`{root, target, observed, proxied, computes}`)
    let isArray = Typeof.array(target)
    let proxy = Proxy.make(
      target,
      {
        "set": set(root, base, observed, proxied, computes, ...),
        "deleteProperty": deleteProperty(root, observed, proxied, computes, ...),
        "get": get(root, base, observed, proxied, computes, meta, isArray, ...),
        "ownKeys": ownKeys(root, observed, ...),
      },
    )
    meta.proxy = proxy
    meta
  }
}

let timeOutFlush = (fn: unit => unit) => {
  ignore(setTimeout(() => {
      fn()
    }, 0))
}

// Public for library developers.
let _observe = (p: 'a, notify) => {
  switch _nmeta(p) {
  | Value({root}) => _setObserver(root, notify)
  | _ => Exn.raiseError("Observed state is not a tilia proxy.")
  }
}

let connect = (root: root) => (branchp: branchp) => {
  // We cheat with types on initial proxy creation.
  let base = {proxy: %raw(`undefined`)}

  // We hide the type of base to avoid typing everything to rootp.
  let proxy = proxify(root, base, branchp).proxy
  base.proxy = %raw(`proxy`)
  proxy
}

let observe = (root: root) => (callback: unit => unit) => {
  let rec notify = () => {
    let o = _setObserver(root, notify)
    callback()
    _ready(o, ~notifyIfChanged=false)
  }
  notify()
}

type computed<'p, 'a> = ('a, 'p => 'a) => 'a

let computed = (callback: 'p => 'a) => {
  let v = {clear: noop, rebuild: callback}
  ignore(Reflect.set(v, computeKey, true))
  %raw(`v`)
}

external connector: (branchp => branchp, (unit => unit) => unit) => tilia<'a> = "connector"

%%raw(`
function connector(connect, observe) {
  return {connect, observe};
}
`)

let make = (~flush=timeOutFlush): tilia<'a> => {
  let root = {flush, observer: Undefined, expired: Undefined}
  connector(connect(root), observe(root))
}
