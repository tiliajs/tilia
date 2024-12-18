module Reflect = {
  external has: ('a, string) => bool = "Reflect.has"
  external get: ('a, string) => 'b = "Reflect.get"
  external set: ('a, string, 'b) => bool = "Reflect.set"
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
module Dict = {
  type t<'a>
  external get: (t<'a>, string) => nullable<'a> = "Reflect.get"
  external set: (t<'a>, string, 'b) => unit = "Reflect.set"
  external remove: (t<'a>, string) => unit = "Reflect.deleteProperty"
}
type dict<'a> = Dict.t<'a>

let indexKey = %raw(`Symbol()`)
let rootKey = %raw(`Symbol()`)
let rawKey = %raw(`Symbol()`)

// Set of observers observing a given key in an object/array
type watchers = Set.t<Symbol.t>
// List of sets to which the the observer should add itself on flush
type collector = array<(dict<watchers>, string)>

type rec observer = {
  // The symbol that will be added to watchers on flush
  watcher: Symbol.t,
  notify: unit => unit,
  // What this observer is observing (a list of watchers)
  collector: collector,
  // Where this observer is observing (used for clear and flush)
  root: root,
}
and root = {
  mutable collecting: option<collector>,
  observers: Map.t<Symbol.t, observer>,
}

let _root: 'a => nullable<root> = p => Reflect.get(p, rootKey)
let _raw: 'a => 'a = p => Reflect.get(p, rawKey)

let _connect = (p: 'a, notify) => {
  switch _root(p) {
  | Value(root) => {
      let observer: observer = {
        watcher: Symbol.make(""),
        notify,
        collector: [],
        root,
      }
      root.collecting = Some(observer.collector)
      observer
    }
  | _ => Exn.raiseError("Observed state is not a tilia proxy.")
  }
}

let _clear = (observer: observer) => {
  let {watcher, root} = observer
  if Map.delete(root.observers, watcher) {
    Array.forEach(observer.collector, ((observed, key)) => {
      switch Dict.get(observed, key) {
      | Value(watchers) =>
        if Set.delete(watchers, watcher) {
          if Set.size(watchers) == 0 {
            // We want to avoid any external deps.
            Dict.remove(observed, key)
          }
        }
      | _ => ()
      }
    })
  }
}

let register = (watcher: Symbol.t, leaf: (dict<watchers>, string)) => {
  let (observed, key) = leaf
  let watchers = switch Dict.get(observed, key) {
  | Value(watchers) => watchers
  | _ =>
    let watchers = Set.make()
    Dict.set(observed, key, watchers)
    watchers
  }
  Set.add(watchers, watcher)
}

let _flush = (observer: observer) => {
  let {root, watcher, collector} = observer
  switch root.collecting {
  | Some(c) if c === collector => root.collecting = None
  | _ => ()
  }
  Map.set(root.observers, watcher, observer)
  Array.forEach(observer.collector, register(watcher, ...))
}

let ownKeys = (root: root, observed: dict<watchers>, target: 'a): 'b => {
  switch root.collecting {
  | Some(c) => Array.push(c, (observed, indexKey))
  | None => ()
  }
  Reflect.ownKeys(target)
}

let notify = (root, observed, key) => {
  switch Dict.get(observed, key) {
  | Value(watchers) =>
    Dict.remove(observed, key)
    Set.forEach(watchers, watcher => {
      switch Map.get(root.observers, watcher) {
      | Some(observer) => {
          _clear(observer)
          observer.notify()
        }
      | None => () // Should never happen
      }
    })
  | _ => ()
  }
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
  } else if key === rawKey {
    %raw(`target`)
  } else {
    switch root.collecting {
    | Some(c) =>
      if isArray && key == "length" {
        Array.push(c, (observed, indexKey))
      } else {
        Array.push(c, (observed, key))
      }
    | None => ()
    }
    // is array and get length
    let v = Reflect.get(target, key)
    if Typeof.object(v) {
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
  }
}

and set = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<'c>,
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
        Dict.remove(proxied, key)
      }
      notify(root, observed, key)
      if !hadKey {
        // new key: trigger index
        notify(root, observed, indexKey)
      }
      true
    }
  }
}

and proxify = (root: root, target: 'a): 'a => {
  let observed: dict<watchers> = %raw(`{}`)
  let proxied: dict<'b> = %raw(`{}`)
  switch _root(target) {
  | Value(r) if r === root => target /* same tree, reuse proxy */
  | Value(_) => proxify(root, _raw(target)) /* external tree: clear */
  | _ =>
    Proxy.make(
      target,
      {
        "set": set(root, observed, proxied, ...),
        "get": get(root, observed, proxied, Typeof.array(target), ...),
        "ownKeys": ownKeys(root, observed, ...),
      },
    )
  }
}

let make = (seed: 'a): 'a => {
  let root = {
    collecting: None,
    observers: Map.make(),
  }
  proxify(root, seed)
}

let observe = (p: 'a, callback: 'a => unit) => {
  let rec notify = () => {
    let o = _connect(p, notify)
    callback(p)
    _flush(o)
  }
  notify()
}
