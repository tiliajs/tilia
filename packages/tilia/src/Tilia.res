module Reflect = {
  external get: ('a, string) => 'b = "Reflect.get"
  external set: ('a, string, 'b) => bool = "Reflect.set"
}
module Proxy = {
  @new external make: ('a, 'b) => 'c = "Proxy"
}
// Set of observers observing a given key in an object/array
type eyes = Set.t<Symbol.t>
// List of sets to which the the observer should add itself on flush
type collector = array<(dict<eyes>, string)>
type observer = {
  // The symbol that will be added to eyes on flush
  sym: Symbol.t,
  notify: unit => unit,
  // What this observer is observing (a list of eyes)
  collector: collector,
}
type root = {
  mutable collector: option<collector>,
  observers: Map.t<Symbol.t, observer>,
}
type t = root
exception CoreBug(string)

let clear = (root: root, observer: observer) => {
  let {sym} = observer
  ignore(Map.delete(root.observers, sym))
  Array.forEach(observer.collector, ((observed, key)) => {
    switch Dict.get(observed, key) {
    | Some(eyes) =>
      if Set.delete(eyes, sym) {
        if Set.size(eyes) == 0 {
          ignore(Dict.delete(observed, key))
        }
      }
    | _ => ()
    }
  })
}

let observe = (sym: Symbol.t, leaf: (dict<eyes>, string)) => {
  let (observed, key) = leaf
  let eyes = switch Dict.get(observed, key) {
  | Some(eyes) => eyes
  | None => {
      let eyes = Set.make()
      Dict.set(observed, key, eyes)
      eyes
    }
  }
  Set.add(eyes, sym)
}

let get = (root: root, observed: dict<eyes>, proxied: dict<'c>, target: 'a, key: string): 'b => {
  switch root.collector {
  | Some(c) => Array.push(c, (observed, key))
  | None => ()
  }
  Reflect.get(target, key)
}

let set = (
  root: root,
  observed: dict<eyes>,
  proxied: dict<'c>,
  target: 'a,
  key: string,
  value: 'b,
) => {
  let prev = Reflect.get(target, key)
  if prev == value {
    true
  } else {
    switch Reflect.set(target, key, value) {
    | false => false
    | true =>
      switch Dict.get(observed, key) {
      | Some(eyes) => {
          Dict.delete(observed, key)
          Set.forEach(eyes, sym => {
            switch Map.get(root.observers, sym) {
            | Some(observer) => {
                clear(root, observer)
                observer.notify()
              }
            | None => raise(CoreBug("Observing sym should always be in root.observers."))
            }
          })
        }
      | None => ()
      }
      true
    }
  }
}

let proxify = (root: root, target: 'a): 'a => {
  let observed: dict<eyes> = Dict.make()
  let proxied: dict<'b> = Dict.make()
  Proxy.make(
    target,
    {
      "set": set(root, observed, proxied, ...),
      "get": get(root, observed, proxied, ...),
    },
  )
}

let init = (seed: 'a): (t, 'a) => {
  let root = {
    collector: None,
    observers: Map.make(),
  }
  (root, proxify(root, seed))
}

let connect = (root, notify) => {
  let observer = {
    sym: Symbol.make("obs"),
    notify,
    collector: [],
  }
  root.collector = Some(observer.collector)
  observer
}

let flush = (root: root, observer: observer) => {
  switch root.collector {
  | Some(c) if c == observer.collector => root.collector = None
  | _ => ()
  }
  Map.set(root.observers, observer.sym, observer)
  Array.forEach(observer.collector, observe(observer.sym, ...))
}
