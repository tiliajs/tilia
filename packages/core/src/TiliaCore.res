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

let indexKey = %raw(`Symbol()`)
let rootKey = %raw(`Symbol()`)
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

type meta<'a> = {
  target: 'a,
  root: root,
  observed: dict<watchers>,
  proxied: dict<Obj.t>,
}

let _root: 'a => nullable<root> = p => Reflect.get(p, rootKey)
let _meta: 'a => meta<'a> = p => Reflect.get(p, metaKey)
let _raw: 'a => 'a = p => _meta(p).target

let _connect = (p: 'a, notify) => {
  switch _root(p) {
  | Value(root) => {
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

let set = (observed: dict<watchers>, proxied: dict<'c>, target: 'a, key: string, value: 'b) => {
  let hadKey = Reflect.has(target, key)
  let prev = Reflect.get(target, key)
  if prev === value {
    true
  } else {
    switch Reflect.set(target, key, value) {
    | false => false
    | true =>
      if Typeof.object(prev) {
        Dict.delete(proxied, key)
      }
      notify(observed, key)
      if !hadKey {
        // new key: trigger index
        notify(observed, indexKey)
      }
      true
    }
  }
}

let deleteProperty = (observed: dict<watchers>, proxied: dict<'c>, target: 'a, key: string) => {
  let res = Reflect.deleteProperty(target, key)
  Dict.delete(proxied, key)
  notify(observed, key)
  res
}

let rec get = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<'c>,
  isArray: bool,
  target: 'a,
  key: string,
): 'b => {
  if key === rootKey {
    %raw(`root`)
  } else if key === metaKey {
    %raw(`{root, target, observed, proxied}`)
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
        | Value(p) => p
        | _ =>
          let p = proxify(root, v)
          Dict.set(proxied, key, p)
          p
        }
      } else {
        v
      }
    } else {
      v
    }
  }
}

and proxify = (root: root, target: 'a): 'a => {
  let observed: dict<watchers> = Dict.make()
  let proxied: dict<'b> = Dict.make()
  switch _root(target) {
  | Value(r) if r === root => target /* same tree, reuse proxy */
  | Value(_) => proxify(root, _raw(target)) /* external tree: clear */
  | _ =>
    Proxy.make(
      target,
      {
        "set": set(observed, proxied, ...),
        "deleteProperty": deleteProperty(observed, proxied, ...),
        "get": get(root, observed, proxied, Typeof.array(target), ...),
        "ownKeys": ownKeys(root, observed, ...),
      },
    )
  }
}

let make = (seed: 'a): 'a => {
  let root = {observer: Undefined}
  proxify(root, seed)
}

let observe = (p: 'a, callback: 'a => unit) => {
  let rec notify = () => {
    let o = _connect(p, notify)
    callback(p)
    _ready(o, ~notifyIfChanged=false)
  }
  notify()
}
