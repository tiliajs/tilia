%%raw(`
if (globalThis["@tilia/core"] === "Loaded") {
  throw new Error("@tilia/core already loaded")
}
globalThis["@tilia/core"] = "Loaded"
`)
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
let rawKey = %raw(`Symbol()`)
let deadKey = %raw(`Symbol()`)

// Set of observers observing a given key in an object/array
type watchers = Set.t<Symbol.t>
// List of sets to which the the observer should add itself on flush
type collector = array<(dict<watchers>, string, watchers)>

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

let setForKey = (observed, key) => {
  switch Dict.get(observed, key) {
  | Value(watchers) => watchers
  | _ =>
    let watchers = Set.make()
    Dict.set(observed, key, watchers)
    watchers
  }
}

let _clear = (observer: observer) => {
  let {watcher, root} = observer
  if Map.delete(root.observers, watcher) {
    Array.forEach(observer.collector, ((observed, key, _)) => {
      switch Dict.get(observed, key) {
      | Value(watchers) =>
        if Set.delete(watchers, watcher) {
          if Set.size(watchers) == 0 {
            // Dict.delete(observed, key)
            ()
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

type notified = {mutable done: bool}

let _flush = (observer: observer, ~notifyIfChanged: bool=true) => {
  let {root, watcher, collector} = observer
  switch root.collecting {
  | Some(c) if c === collector => root.collecting = None
  | _ => ()
  }
  let notified = {done: false}
  Map.set(root.observers, watcher, observer)
  Array.forEach(observer.collector, ((observed, key, watchers)) => {
    if !notified.done {
      if Set.has(watchers, deadKey) {
        if notifyIfChanged {
          notified.done = true
          _clear(observer)
          observer.notify()
        } else {
          let watchers = setForKey(observed, key)
          Set.add(watchers, watcher)
          Array.push(observer.collector, (observed, key, watchers))
        }
      } else {
        Set.add(watchers, watcher)
      }
    }
  })
}

let ownKeys = (root: root, observed: dict<watchers>, target: 'a): 'b => {
  let keys = Reflect.ownKeys(target)
  switch root.collecting {
  | Some(c) => Array.push(c, (observed, indexKey, setForKey(observed, indexKey)))
  // Array.forEach(keys, k => Array.push(c, (observed, k)))
  | None => ()
  }
  keys
}

let notify = (root, observed, key) => {
  switch Dict.get(observed, key) {
  | Value(watchers) =>
    Dict.delete(observed, key)
    Set.forEach(watchers, watcher => {
      switch Map.get(root.observers, watcher) {
      | Some(observer) => {
          _clear(observer)
          observer.notify()
        }
      | None => () // Should never happen
      }
    })
    Set.add(watchers, deadKey)
  | _ => ()
  }
}

let set = (
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
        Dict.delete(proxied, key)
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

let deleteProperty = (
  root: root,
  observed: dict<watchers>,
  proxied: dict<'c>,
  target: 'a,
  key: string,
) => {
  let res = Reflect.deleteProperty(target, key)
  Dict.delete(proxied, key)
  notify(root, observed, key)
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
  } else if key === rawKey {
    %raw(`target`)
  } else {
    // is array and get length
    let v = Reflect.get(target, key)
    let own = Object.hasOwn(target, key)
    if v === undefined || own {
      switch root.collecting {
      | Some(c) =>
        if isArray && key == "length" {
          Array.push(c, (observed, indexKey, setForKey(observed, indexKey)))
        } else {
          Array.push(c, (observed, key, setForKey(observed, key)))
        }
      | None => ()
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
        "set": set(root, observed, proxied, ...),
        "deleteProperty": deleteProperty(root, observed, proxied, ...),
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
    _flush(o, ~notifyIfChanged=false)
  }
  notify()
}
