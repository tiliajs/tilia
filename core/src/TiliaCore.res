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
type dict<'a> = Dict.t<'a>

// Called when something changes in the index (added or removed keys)
let indexKey = %raw(`Symbol()`)
// Called on any change in the object or children (track method)
let trackKey = %raw(`Symbol()`)
// Used to get meta information (mostly for stats)
let metaKey = %raw(`Symbol()`)

type state =
  | Pristine // Hasn't changed since value read.
  | Changed // Value changed and has been notified.
  | Cleared // No more observer registered: cleared.

type rec observer = {
  notify: unit => unit,
  // What this observer is observing (a list of watchers)
  observing: observing,
  // Where this observer is observing (not used anymore ?)
  root: root,
}
// Set of observers observing a given key in an object/array
and watchers = {
  mutable state: state,
  // Tracked key in parent
  key: string,
  // Parent tracking
  observed: dict<watchers>,
  // Set of observers to notify on change.
  observers: Set.t<observer>,
}
and root = {mutable observer: nullable<observer>}
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
  // The observer called by children to propagate tracking.
  propagate: observer,
  // The proxy itself (used by proxied).
  mutable proxy: 'a,
}

let _nmeta: 'a => nullable<meta<'a>> = p => Reflect.get(p, metaKey)
let _meta: 'a => meta<'a> = p => Reflect.get(p, metaKey)

let _connect = (p: 'a, notify) => {
  switch _nmeta(p) {
  | Value({root}) => {
      let observer: observer = {
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

let clear = (observer: observer) => {
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
          clear(observer)
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

let callTrackers = observed => {
  switch Dict.get(observed, trackKey) {
  | Value(watchers) =>
    // Protect against loops
    Dict.delete(observed, trackKey)

    Set.forEach(watchers.observers, observer => {
      // Triggers are not automatically cleared
      observer.notify() // This will call `callTrackers` in the parent.
    })

    Dict.set(observed, trackKey, watchers)
  | _ => ()
  }
}

let notify = (observed, key, trigger) => {
  switch Dict.get(observed, key) {
  | Value(watchers) => {
      Dict.delete(observed, key)
      watchers.state = Changed
      Set.forEach(watchers.observers, observer => {
        clear(observer)
        observer.notify()
      })
    }
  | _ => ()
  }
  if trigger {
    callTrackers(observed)
  }
}

let deleteProxied = (proxied: dict<meta<'a>>, propagate: observer, key: string) => {
  switch Dict.get(proxied, key) {
  | Value(m) =>
    switch Dict.get(m.observed, trackKey) {
    | Value(w) =>
      // Child disconnected: will not trigger tracking anymore
      ignore(Set.delete(w.observers, propagate))
    | _ => ()
    }
  | _ => ()
  }
  Dict.delete(proxied, key)
}

let set = (
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  propagate: observer,
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
      notify(observed, key, true)
      if !hadKey {
        // new key: trigger index
        notify(observed, indexKey, false)
      }
      true
    }
  }
}

let deleteProperty = (
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  propagate: observer,
  target: 'a,
  key: string,
) => {
  let res = Reflect.deleteProperty(target, key)
  deleteProxied(proxied, propagate, key)
  notify(observed, key, true)
  res
}

let rec get = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<meta<'c>>,
  propagate: observer,
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

and proxify = (root: root, propagate: observer, target: 'a): meta<'a> => {
  let proxied: dict<meta<'b>> = Dict.make()
  let observed: dict<watchers> = Dict.make()

  // Register parent tracking propagation
  let w = observeKey(observed, trackKey)
  ignore(Set.add(w.observers, propagate))
  Array.push(propagate.observing, w)

  // Create child tracking propagation observer
  let propagate: observer = {
    notify: () => callTrackers(observed),
    observing: [],
    root,
  }
  switch _nmeta(target) {
  | Value(m) if m.root === root => {
      /* same tree, reuse proxy */
      let w = observeKey(m.observed, trackKey)
      Set.add(w.observers, propagate)
      m
    }
  | Value(m) => proxify(root, propagate, m.target) /* external tree: clear */
  | _ =>
    let meta: meta<'a> = %raw(`{root, target, observed, proxied, propagate}`)
    let isArray = Typeof.array(target)
    let proxy = Proxy.make(
      target,
      {
        "set": set(observed, proxied, propagate, ...),
        "deleteProperty": deleteProperty(observed, proxied, propagate, ...),
        "get": get(root, observed, proxied, propagate, meta, isArray, ...),
        "ownKeys": ownKeys(root, observed, ...),
      },
    )
    meta.proxy = proxy
    meta
  }
}

let make = (seed: 'a): 'a => {
  let root = {observer: Undefined}
  let propagate: observer = {
    notify: () => (),
    observing: [],
    root,
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
