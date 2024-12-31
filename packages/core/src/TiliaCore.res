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

// Set of observers observing a given key in an object/array
type watchers = Set.t<Symbol.t>
// List of sets to which the the observer should add itself on flush
type observing = array<watchers>

type state =
  | Recording // Normal recording, a notify during recording will move to ShouldNotify
  | ShouldNotify // Notify while recording, must trigger callback on _ready
  | RecordingNoNotify // Ignore notify while recording, will not trigger callback on _ready
  | Ready // Normal ready state, triggers callback on notify
  | Cleared // Cleared through _clear (without notify)
  | Notified // Cleared on notify

type rec observer = {
  mutable state: state,
  // The symbol that will be added to watchers on flush
  watcher: Symbol.t,
  notify: unit => unit,
  // What this observer is observing (a list of watchers)
  observing: observing,
  // Where this observer is observing (used for clear and flush)
  root: root,
}
and root = {
  mutable observer: nullable<observer>,
  observers: Map.t<Symbol.t, observer>,
}

type meta<'a> = {
  target: 'a,
  root: root,
  observed: dict<watchers>,
  proxied: dict<Obj.t>,
}

let _root: 'a => nullable<root> = p => Reflect.get(p, rootKey)
let _meta: 'a => meta<'a> = p => Reflect.get(p, metaKey)
let _raw: 'a => 'a = p => _meta(p).target

let _connect = (p: 'a, notify, ~notifyIfChanged: bool=true) => {
  switch _root(p) {
  | Value(root) => {
      let observer: observer = {
        state: notifyIfChanged ? Recording : RecordingNoNotify,
        watcher: Symbol.make(""),
        notify,
        observing: [],
        root,
      }
      Map.set(root.observers, observer.watcher, observer)
      root.observer = Value(observer)
      observer
    }
  | _ => Exn.raiseError("Observed state is not a tilia proxy.")
  }
}

let observeKey = (observer, observed, key) => {
  let w = switch Dict.get(observed, key) {
  | Value(w) => w
  | _ =>
    let w = Set.make()
    Dict.set(observed, key, w)
    w
  }
  Set.add(w, observer.watcher)
  Array.push(observer.observing, w)
}

let _clear = (observer: observer) => {
  let {watcher, root} = observer
  if Map.delete(root.observers, watcher) {
    Array.forEach(observer.observing, watchers => ignore(Set.delete(watchers, watcher)))
  }
  observer.state = Cleared
}

let _ready = (observer: observer) => {
  let {root, state} = observer
  switch root.observer {
  | Value(o) if o === observer => root.observer = Undefined
  | _ => ()
  }
  switch state {
  | ShouldNotify => {
      observer.notify()
      observer.state = Notified
    }
  | Cleared => {
      let {watcher, root} = observer
      Map.set(root.observers, watcher, observer)
      Array.forEach(observer.observing, watchers => ignore(Set.add(watchers, watcher)))
      observer.state = Ready
    }
  | Recording | RecordingNoNotify => observer.state = Ready
  | Ready | Notified => () // Should not happen
  }
}

let ownKeys = (root: root, observed: dict<watchers>, target: 'a): 'b => {
  let keys = Reflect.ownKeys(target)
  switch root.observer {
  | Value(o) => observeKey(o, observed, indexKey)
  | _ => ()
  }
  keys
}

let notify = (root, observed, key) => {
  switch Dict.get(observed, key) {
  | Value(watchers) => {
      let removable = ref(true)
      // We need to freeze the set content before looping because the notification could
      // re-add the observer during this same run and we would loop forever.
      Array.forEach(Set.toArray(watchers), watcher => {
        switch Map.get(root.observers, watcher) {
        | Some(observer) =>
          switch observer.state {
          | Ready => {
              _clear(observer)
              observer.notify()
              observer.state = Notified
            }
          | Recording => {
              _clear(observer)
              observer.state = ShouldNotify
            }
          | RecordingNoNotify => removable.contents = false
          | ShouldNotify => () // These cases should never happen because of previous clear
          | Cleared => ()
          | Notified => ()
          }
        | None => () // Should never happen
        }
      })
      if removable.contents && Set.size(watchers) == 0 {
        Dict.delete(observed, key)
      }
    }
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
          observeKey(o, observed, indexKey)
        } else {
          observeKey(o, observed, key)
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
    observer: Undefined,
    observers: Map.make(),
  }
  proxify(root, seed)
}

let observe = (p: 'a, callback: 'a => unit) => {
  let rec notify = () => {
    let o = _connect(p, notify, ~notifyIfChanged=false)
    callback(p)
    _ready(o)
  }
  notify()
}
