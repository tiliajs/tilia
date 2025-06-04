module Reflect = {
  external has: ('a, string) => bool = "Reflect.has"
  external get: ('a, string) => 'b = "Reflect.get"
  external maybeGet: ('a, string) => nullable<'b> = "Reflect.get"
  external set: ('a, string, 'b) => bool = "Reflect.set"
  external deleteProperty: ('a, string) => bool = "Reflect.deleteProperty"
  external ownKeys: 'a => 'b = "Reflect.ownKeys"
}

module Proxy = {
  @new external make: ('a, 'b) => 'c = "Proxy"
}

let symbol: string => string = %raw(`
function(s) {
  return Symbol.for('tilia:' + s);
}
`)

// Called when something changes in the index (added or removed keys)
let indexKey = symbol("indexKey")
// Used to get meta information (mostly for stats)
let metaKey = symbol("metaKey")
// Mark a function as being a compute value
let computeKey = symbol("computeKey")
// Default context
let ctxKey = symbol("ctx")

// This is also used to detect compute in init state (they have a noop clear
// function).
let noop = () => ()

type compute<'a> = {
  mutable clear: unit => unit,
  mutable rebuild: unit => 'a,
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

  let compute: 'a => nullable<compute<'a>> = %raw(`
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
  computes: 'b. dict<compute<'b>>,
  // The proxy itself (used by proxied).
  mutable proxy: 'a,
}

type signal<'a> = {mutable value: 'a}
type tilia = {
  connect: 'a. 'a => 'a,
  computed: 'a 'b. (unit => 'b) => 'b,
  observe: (unit => unit) => unit,
  signal: 'a. 'a => (signal<'a>, 'a => unit),
  derived: 'a. (unit => 'a) => signal<'a>,
  /** internal */
  _observe: (unit => unit) => observer,
  _ready: (observer, bool) => unit,
  _clear: observer => unit,
  _meta: 'a. 'a => nullable<meta<'a>>,
}

let _meta: 'a => nullable<meta<'a>> = p => Reflect.get(p, metaKey)

@inline
let setObserver = (root, notify) => {
  let observer = {notify, observing: []}
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

let flush = root => {
  switch root.expired {
  | Value(expired) =>
    root.flush(() => {
      root.expired = Undefined
      Set.forEach(expired, observer => observer.notify())
    })
  | _ => ()
  }
}

let clearObserver = (root: root, observer: observer) => {
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
  switch root.observer {
  | Value(o) if o === observer => {
      root.observer = Undefined
      flush(root)
    }
  | _ => ()
  }
}

let setReady = (root: root, observer: observer, notifyIfChanged: bool) => {
  ignore(
    Array.findWithIndex(observer.observing, (w, idx) => {
      switch w.state {
      | Pristine => {
          ignore(Set.add(w.observers, observer))
          false
        }
      | Changed if notifyIfChanged => {
          clearObserver(root, observer)
          observer.notify()
          true // abort find
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
  switch root.observer {
  | Value(o) if o === observer => {
      root.observer = Undefined
      flush(root)
    }
  | _ => ()
  }
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

      // Get expiry set
      let expired = switch root.expired {
      | Value(expired) => expired
      | _ => {
          let expired = Set.make()
          root.expired = Value(expired)
          expired
        }
      }

      // Notify
      Set.forEach(watchers.observers, observer => {
        clearObserver(root, observer)
        Set.add(expired, observer)
      })

      switch root.observer {
      | Value(_) => ()
      // No observers, we can flush
      | _ => flush(root)
      }
    }
  | _ => ()
  }
}

type observerRef = {mutable o: nullable<observer>}
type lastValue<'a> = {mutable v: 'a}

let rec set = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  computes: dict<compute<'b>>,
  target: 'a,
  key: string,
  value: 'b,
) => {
  let hadKey = Reflect.has(target, key)
  let prev = Reflect.get(target, key)
  let proxiable = Typeof.proxiable(value)
  let same = if proxiable {
    switch _meta(value) {
    | Value(m) => m.target === prev
    | _ => prev === value
    }
  } else {
    prev === value
  }
  if same {
    true
  } else {
    switch Reflect.set(target, key, value) {
    | false => false
    | true =>
      if proxiable {
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
        setupComputed(root, observed, proxied, computes, target, key, compute)
        if Dict.has(observed, key) {
          // Computed value is observed: notify
          set(root, observed, proxied, computes, target, key, compute.rebuild())
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
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  computes: dict<compute<'b>>,
  target: 'a,
  key: string,
  compute: compute<'b>,
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
      ignore(set(root, observed, proxied, computes, target, key, rebuild()))
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
    let o: observer = {notify, observing: []}
    observer.o = Value(o)

    let previous = root.observer
    root.observer = Value(o)
    let v = callback(p)
    // Computed should not rebuild on change (recursion is bad in computed
    // because it is not meant to have access to the previous value).
    setReady(root, o, false)
    root.observer = previous

    // No need to check if root.observer is unddefined to trigger
    // flush because computed are not supposed to mutate data.
    v
  }
  compute.rebuild = rebuild

  compute.clear = () => {
    // Clear our cache clearing observer
    switch observer.o {
    | Value(o) => clearObserver(root, o)
    | _ => ()
    }
  }
  Dict.set(computes, key, compute)
}

let deleteProperty = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  computes: dict<compute<'b>>,
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
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  computes: dict<compute<'d>>,
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
              setupComputed(root, observed, proxied, computes, target, key, compute)
            }
            let v = compute.rebuild()
            ignore(Reflect.set(target, key, v))
            if Typeof.proxiable(v) && !Object.readonly(target, key) {
              let m = proxify(root, v)
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
            let m = proxify(root, v)
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

and proxify = (root: root, target: 'a): meta<'a> => {
  let proxied: dict<meta<'b>> = Dict.make()
  let observed: observed = Dict.make()
  let computes: dict<compute<'c>> = Dict.make()

  switch _meta(target) {
  | Value(m) if m.root === root => /* same tree, reuse proxy */
    m
  | Value(m) => proxify(root, m.target) /* external tree: clear */
  | _ =>
    let meta: meta<'a> = %raw(`{root, target, observed, proxied, computes}`)
    let isArray = Typeof.array(target)
    let proxy = Proxy.make(
      target,
      {
        "set": set(root, observed, proxied, computes, ...),
        "deleteProperty": deleteProperty(root, observed, proxied, computes, ...),
        "get": get(root, observed, proxied, computes, meta, isArray, ...),
        "ownKeys": ownKeys(root, observed, ...),
      },
    )
    meta.proxy = proxy
    meta
  }
}

let immediateFlush = (fn: unit => unit) => fn()

let makeConnect = (root: root) => (value: 'a) => {
  if !Typeof.proxiable(value) {
    raise(Invalid_argument("connect: value is not an object or array"))
  }
  proxify(root, value).proxy
}

let makeObserve = (root: root) => (callback: unit => unit) => {
  let rec notify = () => {
    let o = setObserver(root, notify)
    callback()
    setReady(root, o, true)
  }
  notify()
}

let computed = (callback: unit => 'a) => {
  let v = {clear: noop, rebuild: callback}
  ignore(Reflect.set(v, computeKey, true))
  %raw(`v`)
}

// syntax sugar

let makeSignal = (connect: signal<'a> => signal<'a>) => (value: 'c) => {
  let s = connect({value: value})
  let set = v => s.value = v
  (s, set)
}

let makeDerive = connect => fn => connect({value: computed(fn)})

let makeObserve_ = (root: root) => notify => {
  let observer = {notify, observing: []}
  root.observer = Value(observer)
  observer
}

let makeReady_ = (root: root) => (observer, notifyIfChanged) => {
  setReady(root, observer, notifyIfChanged)
}

let makeClear_ = (root: root) => (observer: observer) => {
  clearObserver(root, observer)
}

/* We use this external hack to have polymorphic functions (without this, they
 * become monomorphic).
 */
external connector: (
  // connect
  'a => 'a,
  // computed
  ('x => 'b) => 'b,
  // observe
  (unit => unit) => unit,
  // signal
  'c => (signal<'c>, 'c => unit),
  // derived
  (unit => 'd) => signal<'d>,
  // internal
  // _observe
  (unit => unit) => observer,
  // _ready
  (observer, bool) => unit,
  // _clear
  observer => unit,
  // _meta
  'f => nullable<meta<'f>>,
) => tilia = "connector"

%%raw(`
function connector(connect, computed, observe, signal, derived, _observe, _ready, _clear) {
  return {
    // 
    connect,
    computed, 
    observe,
    signal,
    derived,
    _observe,
    _ready,
    _clear,
    _meta,
  };
}
`)

let make = (~flush=immediateFlush): tilia => {
  let root = {flush, observer: Undefined, expired: Undefined}
  // We need to use raw to hide the types here.
  let connect = makeConnect(root)
  let observe = makeObserve(root)
  let signal = makeSignal(connect)
  connector(
    //
    connect,
    computed,
    observe,
    signal,
    makeDerive(connect),
    makeObserve_(root),
    makeReady_(root),
    makeClear_(root),
    _meta,
  )
}

// Default context
let _ctx = switch Reflect.maybeGet(globalThis, ctxKey) {
| Value(ctx) => ctx
| _ => {
    let ctx = make(~flush=immediateFlush)
    ignore(Reflect.set(globalThis, ctxKey, ctx))
    ctx
  }
}

let connect = _ctx.connect
let observe = _ctx.observe
let signal = _ctx.signal
let derived = _ctx.derived
let _observe = _ctx._observe
let _ready = _ctx._ready
let _clear = _ctx._clear
// _meta (does not need context)
