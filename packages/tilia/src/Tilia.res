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

type rec observer = {
  // The symbol that will be added to eyes on flush
  sym: Symbol.t,
  notify: unit => unit,
  // What this observer is observing (a list of eyes)
  collector: collector,
  // Where this observer is observing (used for clear and flush)
  root: root,
}
and root = {
  mutable collecting: option<collector>,
  observers: Map.t<Symbol.t, observer>,
}
type t<'a> = (root, 'a)
exception CoreBug(string)

let clear = (observer: observer) => {
  let {sym, root} = observer
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
  switch root.collecting {
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
                clear(observer)
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

let make = (seed: 'a): t<'a> => {
  let root = {
    collecting: None,
    observers: Map.make(),
  }
  (root, proxify(root, seed))
}

let _connect = ((root, _), notify) => {
  let observer: observer = {
    sym: Symbol.make("obs"),
    notify,
    collector: [],
    root,
  }
  root.collecting = Some(observer.collector)
  observer
}

let _flush = (observer: observer) => {
  let {root, sym, collector} = observer
  switch root.collecting {
  | Some(c) if c == collector => root.collecting = None
  | _ => ()
  }
  Map.set(root.observers, sym, observer)
  Array.forEach(observer.collector, observe(sym, ...))
}

let observe = (t: t<'a>, callback: 'a => unit) => {
  let (_, p) = t
  let rec notify = () => {
    let o = _connect(t, notify)
    callback(p)
    _flush(o)
  }
  notify()
}
