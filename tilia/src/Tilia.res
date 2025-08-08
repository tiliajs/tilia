module Reflect = {
  external has: ('a, string) => bool = "Reflect.has"
  external get: ('a, string) => 'b = "Reflect.get"
  external maybeGet: ('a, string) => nullable<'b> = "Reflect.get"
  external set: ('a, string, 'b) => bool = "Reflect.set"
  external deleteProperty: ('a, string) => bool = "Reflect.deleteProperty"
  external ownKeys: 'a => 'b = "Reflect.ownKeys"
}

let raise: string => 'a = %raw(`function (message) {
  throw new Error(message)
}`)

module Proxy = {
  @new external make: ('a, 'b) => 'c = "Proxy"
}

let symbol: string => string = %raw(`
function(s) {
  return Symbol.for('tilia:' + s);
}
`)

let defaultGc = 50

// Called when something changes in the index (added or removed keys)
let indexKey = symbol("indexKey")
// Used to get meta information (mostly for stats)
let metaKey = symbol("metaKey")
// Mark a function as being a compute value
let dynamicKey = symbol("dynamicKey")
// Default context
let ctxKey = symbol("ctx")

type compute<'a> = {mutable rebuild: unit => 'a}

type source<'a, 'ignored> = {
  source: ('a => unit) => 'ignored,
  value: 'a,
}

type dynamic<'a, 'b> =
  | Computed(unit => 'a)
  | Source(source<'a, 'b>)
  | Store(('a => unit) => 'a)
  | Compiled(compute<'a>)

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

  let dynamic: 'a => nullable<dynamic<'a, 'b>> = %raw(`
function(v) {
  return typeof v === 'object' && v !== null && v[dynamicKey] ? v : undefined;
}
  `)
}

module Object = {
  type descriptor<'a> = {writable: bool, enumerable: bool, configurable: bool, value: 'a}
  external hasOwn: ('a, string) => bool = "Object.hasOwn"
  external getOwnPropertyDescriptor: ('a, string) => nullable<descriptor<'b>> =
    "Object.getOwnPropertyDescriptor"
  let readonly: ('a, string) => bool = (o, k) => {
    switch getOwnPropertyDescriptor(o, k) {
    | Value(d) => d.writable === false
    | _ => false
    }
  }
  external defineProperty: ('a, string, descriptor<'b>) => unit = "Object.defineProperty"
}

module Dict = {
  type t<'a>
  @new external make: unit => t<'a> = "Map"
  @send external get: (t<'a>, string) => nullable<'a> = "get"
  @send external set: (t<'a>, string, 'b) => unit = "set"
  @send external delete: (t<'a>, string) => unit = "delete"
}

type dict<'a> = Dict.t<'a>

type state =
  | Pristine // Hasn't changed since value read.
  | Changed // Value changed and has been notified.
  | Cleared // No more observer registered: cleared.

type rec observer = {
  // We set root in the observer so that most methods do not need to
  // be recreated in the tilia context.
  root: root,
  // Function to call on notify.
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
and gc = {
  mutable active: Set.t<watchers>,
  mutable quarantine: Set.t<watchers>,
  threshold: int,
}
and root = {
  mutable observer: nullable<observer>,
  // List of watchers to clear on next flush
  mutable expired: Set.t<observer>,
  // If set to true, wait for end of batch before flush
  mutable lock: bool,
  // Garbage collection handling
  gc: gc,
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
  computes: dict<unit => unit>,
  // The proxy itself (used by proxied).
  mutable proxy: 'a,
}

type signal<'a> = {mutable value: 'a}
type readonly<'a> = {data: 'a}
type setter<'a> = 'a => unit
type deriver<'p> = {
  /** 
   * Return a derived value to be inserted into a tilia object. This is like
   * a computed but with the tilia object as parameter.
   * 
   * @param f The computation function that takes the tilia object as parameter.
   */
  derived: 'a. ('p => 'a) => 'a,
}
type tilia = {
  tilia: 'a. 'a => 'a,
  carve: 'a. (deriver<'a> => 'a) => 'a,
  observe: (unit => unit) => unit,
  watch: 'a. (unit => 'a, 'a => unit) => unit,
  batch: (unit => unit) => unit,
  signal: 'a. 'a => signal<'a>,
  derived: 'a. (unit => 'a) => signal<'a>,
  /** internal */
  _observe: (unit => unit) => observer,
}

let _meta: 'a => nullable<meta<'a>> = p => Reflect.get(p, metaKey)

@inline
let _observe = (root, notify) => {
  let observer = {root, notify, observing: []}
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
  if Set.size(root.expired) > 0 {
    while Set.size(root.expired) > 0 {
      let expired = root.expired
      root.expired = Set.make()
      Set.forEach(expired, observer => observer.notify())
    }
  }

  let gc = root.gc
  if Set.size(gc.active) >= gc.threshold {
    Set.forEach(gc.quarantine, w => {
      if w.state === Pristine && Set.size(w.observers) === 0 {
        w.state = Cleared
        Dict.delete(w.observed, w.key)
      }
    })

    gc.quarantine = gc.active
    gc.active = Set.make()
  }
}

let _clear = (observer: observer) => {
  let root = observer.root
  Array.forEach(observer.observing, watchers => {
    if (
      watchers.state == Pristine &&
      // No need to delete if state isn't Pristine
      Set.delete(watchers.observers, observer) &&
      Set.size(watchers.observers) === 0
    ) {
      // Add to gc set
      Set.add(root.gc.active, watchers)
    }
  })
  switch root.observer {
  | Value(o) if o === observer => {
      root.observer = Undefined
      if !root.lock {
        flush(root)
      }
    }
  | _ => ()
  }
}

let _ready = (observer: observer, notifyIfChanged: bool) => {
  ignore(
    Array.findWithIndex(observer.observing, (w, idx) => {
      switch w.state {
      | Pristine => {
          ignore(Set.add(w.observers, observer))
          false
        }
      | Changed | Cleared if notifyIfChanged => {
          _clear(observer)
          observer.notify()
          true // abort find
        }
      | _ => {
          // Cleared or Changed, but without notifyIfChanged.
          // We need to re-subscribe to the key
          let w = observeKey(w.observed, w.key)
          ignore(Set.add(w.observers, observer))
          observer.observing[idx] = w
          false
        }
      }
    }),
  )
  let root = observer.root
  switch root.observer {
  | Value(o) if o === observer => {
      root.observer = Undefined
      if !root.lock {
        flush(root)
      }
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

      let expired = root.expired

      // Notify
      Set.forEach(watchers.observers, observer => {
        _clear(observer)
        Set.add(expired, observer)
      })

      switch root.observer {
      | Value(_) => ()
      // No observers, we can flush
      | _ =>
        if !root.lock {
          flush(root)
        }
      }
    }
  | _ => ()
  }
}

@inline
let sourceCallback = (set, source: source<'a, 'b>) => {
  let v = source.value
  let val = ref(v)
  let set = v => {
    val := v
    set(v)
  }
  let callback = source.source
  // Set initial value
  set(v)
  () => {
    callback(set)
    val.contents
  }
}

@inline
let storeCallback = (set, callback) => {
  // Set initial value
  () => callback(set)
}

@inline
let getValue = (compile, set, value) => {
  let rec get = value => {
    switch Typeof.dynamic(value) {
    | Undefined | Null => value
    | Value(dynamic) => {
        let v = switch dynamic {
        | Compiled({rebuild}) => rebuild()
        | Computed(callback) => compile(callback)
        | Source(source) => compile(sourceCallback(set, source))
        | Store(store) => compile(storeCallback(set, store))
        }
        Typeof.proxiable(v) ? get(v) : v
      }
    }
  }
  get(value)
}

type observerRef = {mutable o: nullable<observer>}
type lastValue<'a> = {mutable v: 'a}

let rec set = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  computes: dict<unit => unit>,
  isArray: bool,
  fromComputed: bool,
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
      let key = if isArray && key === "length" {
        indexKey
      } else {
        key
      }

      if proxiable {
        Dict.delete(proxied, key)
      }
      if !fromComputed {
        // New computed value (install it and only notify is needed)
        switch Dict.get(computes, key) {
        | Value(clear) => {
            // Updating the compute function: clear old one.
            Dict.delete(computes, key)
            clear()
          }
        | _ => ()
        }
      }
      switch Typeof.dynamic(value) {
      | Undefined | Null => {
          notify(root, observed, key)
          if !hadKey {
            // new key: trigger index
            notify(root, observed, indexKey)
          }
          true
        }
      | Value(_) =>
        // Dynamic value
        switch Dict.get(observed, key) {
        | Value(w) if w.state === Pristine && Set.size(w.observers) > 0 => {
            // Computed value is observed: rebuild and notify if changed
            // Put back previous value to detect changes
            ignore(Reflect.set(target, key, prev))
            let compile = callback =>
              compile(root, observed, proxied, computes, isArray, target, key, callback)
            let setter = v =>
              ignore(set(root, observed, proxied, computes, isArray, true, target, key, v))
            let v = getValue(compile, setter, value)
            set(root, observed, proxied, computes, isArray, true, target, key, v)
          }
        | _ => true
        }
      }
    }
  }
}

and compile = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  computes: dict<unit => unit>,
  isArray: bool,
  target: 'a,
  key: string,
  callback: unit => 'b,
) => {
  let lastValue: lastValue<'b> = {v: %raw(`undefined`)}
  let observer = {o: Undefined}
  // Initial compute has raw callback as rebuild method
  let compute: compute<'b> = {
    rebuild: %raw(`undefined`),
  }

  let compiled = Compiled(compute)
  ignore(Reflect.set(compiled, dynamicKey, true))

  let rec notify = () => {
    let v = Reflect.get(target, key)
    if v !== compiled {
      lastValue.v = v
    }

    switch Dict.get(observed, key) {
    | Value(w) if Set.size(w.observers) > 0 =>
      // We have active observers on this key.
      // Rebuild and if the key changed, it will notify.
      ignore(set(root, observed, proxied, computes, isArray, true, target, key, rebuild()))
    | Value(w) => {
        // No active listeners.
        w.state = Changed
        Dict.delete(observed, key)
        ignore(Dict.delete(proxied, key))
        ignore(Reflect.set(target, key, compiled))
      }
    | _ => {
        // We do not have any observers: reset value.
        // Make sure the previous proxy (if any) is removed so that it is not
        // served in place of triggering the compute.
        ignore(Dict.delete(proxied, key))
        ignore(Reflect.set(target, key, compiled))
      }
    }
  }
  and rebuild = () => {
    // Make sure any further read gets the last value until we are done with
    // rebuilding the value. This is also useful if the callback needs the
    // previous value and to detect unchanged value.  If possible, the callback
    // should avoid accessing this value because it can be undefined on first
    // run and breaks typing.
    let curr = Reflect.get(target, key)
    if curr === compiled {
      ignore(Reflect.set(target, key, lastValue.v))
    } else {
      lastValue.v = curr
    }
    let o: observer = {root, notify, observing: []}
    observer.o = Value(o)

    let previous = root.observer
    root.observer = Value(o)
    let v = callback()

    // We need to reset previous observer before calling setReady so that
    // setReady does not trigger flush.
    root.observer = previous

    // Computed should not rebuild on change.

    if Array.length(o.observing) === 0 {
      // FIXME: How to clear if the rebuild is observing itself ?
      _clear(o)
      Dict.delete(computes, key)
    } else {
      _ready(o, false)
    }
    v
  }
  compute.rebuild = rebuild

  let clear = () => {
    // Clear our cache clearing observer
    switch observer.o {
    | Value(o) => {
        _clear(o)
        // Empty in case "ready" is called after clear (but we only
        // do this for computed).
        ignore(%raw(`o.observing.length = 0`))
      }
    | _ => ()
    }
  }
  Dict.set(computes, key, clear)
  rebuild()
}

let deleteProperty = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  computes: dict<unit => unit>,
  target: 'a,
  key: string,
) => {
  let res = Reflect.deleteProperty(target, key)
  Dict.delete(proxied, key)
  switch Dict.get(computes, key) {
  | Value(clear) => {
      Dict.delete(computes, key)
      clear()
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
  computes: dict<unit => unit>,
  meta: meta<'a>,
  isArray: bool,
  target: 'a,
  key: string,
): 'b => {
  if key === metaKey {
    // We use this to avoid argument removal by compilation (it is not included
    // in JS compiled code).
    ignore(meta)
    // We use raw to avoid type
    %raw(`meta`)
  } else if key === dynamicKey {
    %raw(`undefined`)
  } else {
    // is array and get length
    let value = Reflect.get(target, key)
    let own = Object.hasOwn(target, key)
    if value === undefined || own {
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

      if Typeof.proxiable(value) && !Object.readonly(target, key) {
        switch Dict.get(proxied, key) {
        | Value(m) => m.proxy
        | _ => {
            let compile = callback =>
              compile(root, observed, proxied, computes, isArray, target, key, callback)
            let setter = v =>
              ignore(set(root, observed, proxied, computes, isArray, true, target, key, v))
            let v = getValue(compile, setter, value)
            ignore(Reflect.set(target, key, v))
            if Typeof.proxiable(v) {
              let m = proxify(root, v)
              Dict.set(proxied, key, m)
              m.proxy
            } else {
              v
            }
          }
        }
      } else {
        // Not proxiable or readonly
        value
      }
    } else {
      // Prototype value
      value
    }
  }
}

and proxify = (root: root, target: 'a): meta<'a> => {
  let proxied: dict<meta<'b>> = Dict.make()
  let observed: observed = Dict.make()
  let computes: dict<unit => unit> = Dict.make()

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
        "set": set(root, observed, proxied, computes, isArray, false, ...),
        "deleteProperty": deleteProperty(root, observed, proxied, computes, ...),
        "get": get(root, observed, proxied, computes, meta, isArray, ...),
        "ownKeys": ownKeys(root, observed, ...),
      },
    )
    meta.proxy = proxy
    meta
  }
}

let _done = (o: observer) => o.root.observer = Undefined

let makeTilia = (root: root) => (value: 'a) => {
  if !Typeof.proxiable(value) {
    raise("tilia: value is not an object or array")
  }
  proxify(root, value).proxy
}

let makeDerived = p => fn => {
  let v = Computed(() => fn(p.contents))
  ignore(Reflect.set(v, dynamicKey, true))
  %raw(`v`)
}

external makeReactive: (
  // derived
  ('p => 'a) => 'a
) => deriver<'p> = "makeReactive"

%%raw(`
function makeReactive(derived) {
  return { derived }
}
`)

let makeCarve = (root: root) => (fn: deriver<'a> => 'a) => {
  let p = ref(%raw(`{}`))
  let ctx = makeReactive(makeDerived(p))
  let value = fn(ctx)
  if !Typeof.proxiable(value) {
    raise("tilia: value is not an object or array")
  }
  let value = proxify(root, value).proxy
  p := value
  value
}

let makeObserve = (root: root) => (callback: unit => unit) => {
  let rec notify = () => {
    let o = _observe(root, notify)
    callback()
    _ready(o, true)
  }
  notify()
}

let makeWatch = (root, observe_) => (callback: unit => 'a, effect: 'a => unit) => {
  let rec notify = () => {
    let o = observe_(notify)
    let v = callback()
    _done(o)
    if root.lock {
      effect(v)
    } else {
      root.lock = true
      effect(v)
      root.lock = false
    }
    _ready(o, false)
  }
  // First registration: effect not called
  let o = observe_(notify)
  ignore(callback())
  _ready(o, false)
}

let makeBatch = (root: root) => (callback: unit => unit) => {
  if root.lock {
    callback()
  } else {
    root.lock = true
    callback()
    root.lock = false
    flush(root)
  }
}

let computed = fn => {
  let v = Computed(fn)
  ignore(Reflect.set(v, dynamicKey, true))
  %raw(`v`)
}

let source = (source, value) => {
  let v = Source({value, source})
  ignore(Reflect.set(v, dynamicKey, true))
  %raw(`v`)
}

let store = callback => {
  let v = Store(callback)
  ignore(Reflect.set(v, dynamicKey, true))
  %raw(`v`)
}

@inline
let makeSignal = (tilia: signal<'a> => signal<'a>) => (value: 'c) => tilia({value: value})
let makeDerived = (tilia: signal<'a> => signal<'a>) => (fn: 'c) =>
  tilia({value: computed(() => fn())})

let _done = (o: observer) => o.root.observer = Undefined

/* We use this external hack to have polymorphic functions (without this, they
 * become monomorphic).
 */
external connector: (
  // tilia
  'a => 'a,
  // carve
  (deriver<'c> => 'c) => 'c,
  // observe
  (unit => unit) => unit,
  // watch
  (unit => 'w, 'w => unit) => unit,
  // batch
  (unit => unit) => unit,
  // extra
  // signal
  's => signal<'s>,
  // derived
  (unit => 't) => signal<'t>,
  // internal
  // _observe
  (unit => unit) => observer,
) => tilia = "connector"

%%raw(`
function connector(tilia, carve, observe, watch, batch, signal, derived, _observe) {
  return {
    tilia,
    carve,
    observe,
    watch,
    batch,
    // extra
    signal,
    derived,
    // internal
    _observe,
  };
}
`)

let make = (~gc=defaultGc): tilia => {
  let gc = {
    active: Set.make(),
    quarantine: Set.make(),
    threshold: gc,
  }
  let root = {observer: Undefined, expired: Set.make(), lock: false, gc}
  // We need to use raw to hide the types here.
  let tilia = makeTilia(root)
  let _observe = _observe(root, ...)

  connector(
    tilia,
    makeCarve(root),
    makeObserve(root),
    makeWatch(root, _observe),
    makeBatch(root),
    // extra
    makeSignal(tilia),
    makeDerived(tilia),
    // Internal
    _observe,
  )
}

// Default context
let _ctx = switch Reflect.maybeGet(globalThis, ctxKey) {
| Value(ctx) => ctx
| _ => {
    let ctx = make()
    ignore(Reflect.set(globalThis, ctxKey, ctx))
    ctx
  }
}

let readonly = (data: 'a) => {
  let obj: readonly<'a> = %raw(`{}`)
  Object.defineProperty(
    obj,
    "data",
    {value: data, enumerable: true, writable: false, configurable: false},
  )
  obj
}

let unwrap = s => computed(() => s.value)

let tilia = _ctx.tilia
let carve = _ctx.carve
let observe = _ctx.observe
let watch = _ctx.watch
let batch = _ctx.batch
// extra
let signal = _ctx.signal
let derived = _ctx.derived

// internal
let _observe = _ctx._observe
// Opaque type for library developers
let _meta: 'a => nullable<'b> = p => Reflect.get(p, metaKey)
