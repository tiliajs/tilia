open Ava
let onot = not
module OSkip = Skip
open Assert
let not = onot
module Skip = OSkip
open Tilia

module TestObject = {
  type t
  let make: unit => t = %raw(`() => ({})`)
  external get: (t, string) => string = "Reflect.get"
  external set: (t, string, string) => unit = "Reflect.set"
  external remove: (t, string) => unit = "Reflect.deleteProperty"
  external keys: t => array<string> = "Object.keys"
}

module AnyObject = {
  type descriptor<'a> = {writable: bool, value: 'a}
  external get: ('a, string) => 'b = "Reflect.get"
  external set: ('a, string, 'b) => bool = "Reflect.set"
  external deleteProperty: ('a, string) => unit = "Reflect.deleteProperty"
  external getOwnPropertyDescriptor: ('a, string) => nullable<descriptor<'b>> =
    "Object.getOwnPropertyDescriptor"
  external defineProperty: ('a, string, descriptor<'b>) => unit = "Object.defineProperty"

  let setReadonly: ('a, string, 'b) => unit = (o, k, v) => {
    defineProperty(o, k, {writable: false, value: v})
  }
  let readonly: ('a, string) => bool = (o, k) => {
    switch getOwnPropertyDescriptor(o, k) {
    | Value(d) => d.writable === false
    | _ => false
    }
  }
}

type user = {mutable name: string, mutable username: string}
type address = {mutable city: string, mutable zip: int}
type person = {
  mutable name: string,
  mutable address: address,
  mutable phone: nullable<string>,
  mutable other_address: address,
  mutable passions: array<string>,
  mutable notes: TestObject.t,
}
type tester = {mutable called: bool}
type error = {mutable message: option<string>}

let apply = fn => fn()

let person = () => {
  name: "John",
  address: {
    city: "Truth",
    zip: 1234,
  },
  phone: Undefined,
  other_address: {
    city: "Beauty",
    zip: 5678,
  },
  passions: ["fruits"],
  notes: TestObject.make(),
}

test("Should observe leaf changes", t => {
  let m = {called: false}
  let p = tilia({name: "John", username: "jo"})
  let o = _observe(() => m.called = true)
  t->is(p.name, "John") // observe 'name'
  t->is(m.called, false)
  _ready(o, true)

  // Update name with same value after ready
  p.name = "John"
  // Callback should not be called
  t->is(m.called, false)

  // Update name with another value after ready
  p.name = "Mary"
  // Callback should be called
  t->is(m.called, true)
  m.called = false

  // Update again
  p.name = "Three"
  // Callback should not be called
  t->is(m.called, false)
})

test("Should observe", t => {
  open String
  let p = {name: "John", username: "jo"}
  let p = tilia(p)
  observe(() => {
    p.username = p.name->toLowerCase->slice(~start=0, ~end=2)
  })

  t->is(p.username, "jo")

  // Update with same name
  p.name = "John"
  // Observing callback not called
  t->is(p.username, "jo")

  // Update with another name
  p.name = "Mary"
  // Observing callback called
  t->is(p.username, "ma")
})

test("Should allow mutating in observed", t => {
  let p = {name: "John", username: "jo"}
  let p = tilia(p)
  observe(() => {
    if !(p.name->String.endsWith("OK")) {
      p.name = p.name ++ " OK"
    }
  })

  t->is(p.name, "John OK")

  // Update with same name
  p.name = "John OK"
  // Observing callback not called
  t->is(p.name, "John OK")

  // Update with another name
  p.name = "Mary"
  // Observing callback called
  t->is(p.name, "Mary OK")
})

test("Should observe mutated keys", t => {
  let p = {name: "John", username: "jo"}
  let p = tilia(p)
  observe(() => {
    if p.username === "john" {
      p.username = "not john"
    }
  })
  p.username = "john"
  t->is(p.username, "not john")

  p.username = "mary"
  t->is(p.username, "mary")

  p.username = "john"
  t->is(p.username, "not john")
})

test("Should proxy sub-objects", t => {
  let m = {called: false}
  let p = person()
  let p = tilia(p)
  let o = _observe(() => m.called = true)
  t->is(p.address.city, "Truth") // observe 'address.city'
  t->is(m.called, false)
  _ready(o, true)

  // Update name with same value after ready
  p.address.city = "Truth"
  // Callback should not be called
  t->is(m.called, false)

  // Update name with another value after ready
  p.address.city = "Kindness"
  // Callback should be called
  t->is(m.called, true)
  m.called = false

  // Update again
  p.address.city = "Sorrow"
  // Callback should not be called
  t->is(m.called, false)
})

test("Should proxy array", t => {
  let m = {called: false}
  let p = person()
  let p = tilia(p)
  let o = _observe(() => m.called = true)
  t->is(p.passions[0], Some("fruits")) // observe key 0
  _ready(o, true)

  // Update entry
  p.passions[0] = "watercolor"
  // Callback should be called
  t->is(m.called, true)
})

test("Should watch array index", t => {
  let m = {called: false}
  let p = person()
  let p = tilia(p)
  let o = _observe(() => m.called = true)
  t->is(Array.length(p.passions), 1) // observe length
  _ready(o, true)

  // Insert new entry
  Array.push(p.passions, "watercolor")
  // Callback should be called
  t->is(m.called, true)
})

test("Should watch object keys", t => {
  let m = {called: false}
  let p = person()
  let p = tilia(p)
  let o = _observe(() => m.called = true)
  t->is(Array.length(TestObject.keys(p.notes)), 0) // observe keys
  _ready(o, true)

  // Insert new entry
  TestObject.set(p.notes, "2024-12-07", "Rebuilding Tilia in ReScript")
  // Callback should be called
  t->is(m.called, true)
})

test("Should not watch each object key", t => {
  let m = {called: false}
  let p = person()
  TestObject.set(p.notes, "day", "Seems ok")
  TestObject.set(p.notes, "night", "Seems good")
  let p = tilia(p)
  let o = _observe(() => m.called = true)
  t->is(Array.length(TestObject.keys(p.notes)), 2) // observe keys
  _ready(o, true)

  // Insert new entry
  TestObject.set(p.notes, "night", "Full of stars")
  // Callback should not be called
  t->is(m.called, false)
})

test("Should not clone added objects", t => {
  let p = person()
  let a = {
    city: "Storm",
    zip: 9999,
  }
  let p = tilia(p)
  p.address = a

  t->is(p.address.city, "Storm")

  // Changing sub-object
  p.address.city = "Rain"

  // Changes original
  t->is(a.city, "Rain")
})

test("Should share tracking in same tree", t => {
  let m = {called: false}
  let p = person()
  let p = tilia(p)
  let o = _observe(() => m.called = true)
  t->is(p.address.city, "Truth") // observe 'city'
  _ready(o, true)
  t->isFalse(m.called)
  p.other_address = p.address
  p.other_address.city = "Love"
  // Should share the same proxy branch
  t->isTrue(p.address === p.other_address)

  t->isTrue(m.called)
})

test("Should not share tracking in another forest", t => {
  let m = {called: false}
  let ctx1 = make(~flush=apply)
  let ctx2 = make(~flush=apply)
  let p1 = ctx1.tilia(person())
  let p2 = ctx2.tilia(person())
  ctx1.observe(() => {
    // observe 'city'
    t->is(p1.address.city, p1.address.city)
    m.called = true
  })
  m.called = false
  t->isFalse(m.called)

  // Shares the same target, but not the same proxy
  p2.other_address = p1.address
  p2.other_address.city = "Love"
  // Should not call observer on p1
  t->isFalse(m.called)
  // The value changed without proxy call (target is the same).
  t->is(p1.address.city, "Love")
  p1.address.city = "Life"
  t->isTrue(m.called)
})

test("Should notify on key deletion", t => {
  let m = {called: false}
  let p = tilia(person())
  TestObject.set(p.notes, "hello", "Everyone")
  let o = _observe(() => m.called = true)
  t->is(TestObject.get(p.notes, "hello"), "Everyone") // observe "hello" key
  _ready(o, true)

  // Remove entry
  TestObject.remove(p.notes, "hello")
  // Callback should be called
  t->is(m.called, true)
})

test("Should not proxy or watch prototype methods", t => {
  let m = {called: false}
  let p = tilia(person())
  let o = _observe(() => m.called = true)
  let x = TestObject.get(p.notes, "constructor")
  t->isTrue(x === TestObject.get(%raw(`{}`), "constructor"))
  _ready(o, true)

  // Edit
  TestObject.set(p.notes, "constructor", "haha")
  // Callback should be called
  t->is(m.called, false)
})

test("Should not proxy readonly properties", t => {
  let m = {called: false}
  let p1 = person()
  let tree = %raw(`{}`)
  AnyObject.setReadonly(tree, "person", p1)
  t->isTrue(AnyObject.readonly(tree, "person"))
  let tree = tilia(tree)
  let o = Tilia._observe(() => m.called = true)
  let p2 = AnyObject.get(tree, "person")
  t->isTrue(p2 === p1)
  _ready(o, true)

  // Cannot set
  t->isFalse(AnyObject.set(tree, "person", person()))

  // Callback should not be called
  t->is(m.called, false)

  // Exact original value is always returned
  t->isTrue(AnyObject.get(tree, "person") === p1)
})

test("Should observe undefined values", t => {
  let m = {called: false}
  let p = person()
  let p = tilia(p)
  let o = _observe(() => m.called = true)
  let phone = p.phone
  t->isTrue(phone === Undefined)
  _ready(o, true)

  p.phone = Value("123 456 789")
  // Callback should be called
  t->is(m.called, true)
})

test("Should notify if update before ready", t => {
  let m = {called: false}
  let p = person()
  let p = tilia(p)
  let o = Tilia._observe(() => m.called = true)
  t->is(p.name, "John") // observe 'name'
  t->is(m.called, false)

  // Update name before ready
  p.name = "One"
  // Callback should not be called
  t->is(m.called, false)
  _ready(o, true)
  // Callback should be called during ready
  t->is(m.called, true)
})

test("Should notify on many updates before ready", t => {
  let m = {called: false}
  let p = person()
  let p = tilia(p)
  let o = _observe(() => m.called = true)
  t->is(p.name, "John") // observe 'name'
  t->is(m.called, false)

  _ready(o, true)
  p.name = "One"
  p.name = "Two"
  p.name = "Three"
  // Callback should be called during ready
  t->is(m.called, true)
})

test("Should clear common key on clear", t => {
  let m1 = {called: false}
  let m2 = {called: false}
  let p = person()
  let p = tilia(p)
  let o1 = _observe(() => m1.called = true)
  t->is(p.name, "John") // o1 observe 'name'
  let o2 = _observe(() => m2.called = true)
  t->is(p.name, "John") // o2 observe 'name'
  _ready(o1, true) // o1 register, o2 not registered
  _clear(o1) // removes watchers (set empty)
  _ready(o2, true)
  t->is(m2.called, false)

  // Update 'name'
  p.name = "Mary"
  // Callback should be called
  t->is(m2.called, true)
})

// React strict mode
test("Should support ready, clear, ready", t => {
  let m = {called: false}
  let p = person()
  let p = tilia(p)
  let o = _observe(() => m.called = true)
  t->is(p.name, "John") // o observe 'name'
  _ready(o, true)
  _clear(o)
  _ready(o, true)
  t->is(m.called, false)

  // Update 'name'
  p.name = "Mary"
  // Callback should be called
  t->is(m.called, true)
})

type item = {
  mutable name: string,
  mutable quantity: int,
}

type items = {
  all: array<item>,
  mutable sorted: array<item>,
  mutable selected: option<item>,
}

test("Should support sub-object in array", t => {
  open Option
  let m = {called: false}
  let items = tilia({
    all: [
      {name: "banana", quantity: 4},
      {name: "carrot", quantity: 8},
      {name: "apple", quantity: 2},
    ],
    // apple
    // banana
    // carrot
    sorted: [],
    selected: None,
  })
  items.sorted = computed(() => Array.toSorted(items.all, (a, b) => String.compare(a.name, b.name)))
  let o = _observe(() => m.called = true)
  t->is(getExn(items.sorted[2]).name, "carrot") // o observe [2] and [2].name
  _ready(o, true)
  items.selected = items.all[1] // carrot
  t->is(m.called, false)
  getExn(items.selected).name = "avocado"
  t->is(m.called, true)
  t->is(getExn(items.sorted[2]).name, "banana")
  // apple
  // avocado (ex carrot)
  // banana
})

type simple_person = {
  mutable name: string,
  mutable username: string,
  address: address,
}

type watchers = {
  // Tracked key in parent
  key: string,
  // Set of observers to notify on change.
  observers: Set.t<Tilia.observer>,
}

type rec meta<'a> = {
  target: 'a,
  observed: Map.t<string, watchers>,
  proxied: Map.t<string, meta<address>>,
  proxy: 'a,
}

// We need this becausee 'Tilia.meta' is an opaque type, not exposed to
// avoid having to fix it (it is an internal type).
let typeMeta: nullable<Tilia.meta<'a>> => nullable<meta<'a>> = _m => %raw(`_m`)

test("Should get internals with _meta", t => {
  let person = {
    name: "Mary",
    username: "mama78",
    address: {city: "Los Angleless", zip: 1234},
  }
  let p = tilia(person)
  observe(() => {
    p.username = p.name
    p.username = p.address.city
  })
  let o = _observe(_ => ())
  t->is("Los Angleless", p.address.city)
  _ready(o, true)

  switch typeMeta(Tilia._meta(p)) {
  | Value(meta) => {
      t->is(person, meta.target)
      let n = Option.getExn(Map.get(meta.observed, "name"))
      t->is(1, Set.size(n.observers))

      let address = Option.getExn(Map.get(meta.proxied, "address")).proxy
      t->is(p.address, address)

      let meta = typeMeta(Tilia._meta(address))
      switch meta {
      | Value(meta) => {
          t->is(person.address, meta.target)
          let n = Option.getExn(Map.get(meta.observed, "city"))
          t->is(2, Set.size(n.observers))
        }
      | _ => t->fail("Meta is undefined")
      }
    }
  | _ => t->fail("Meta is undefined")
  }
})

test("Should clear if ready never called", t => {
  let m = {called: false}
  let p = person()
  let p = tilia(p)
  let _ = _observe(() => m.called = true)
  t->is(p.name, "John") // o observe 'name'

  // Ready never called
  // Observers should be zero
  switch typeMeta(Tilia._meta(p)) {
  | Value(meta) => {
      let n = Option.getExn(Map.get(meta.observed, "name"))
      t->is(0, Set.size(n.observers))
    }
  | _ => t->fail("Meta is undefined")
  }
})

type people = dict<person>

test("Should delete observations on set", t => {
  let p: people = Dict.make()
  Dict.set(p, "john", person())
  let m = {called: false}
  let p = tilia(p)
  let o = _observe(() => m.called = true)
  let j = Dict.getUnsafe(p, "john")
  t->is(j.name, "John") // o observe 'john.name'
  _ready(o, true)

  switch typeMeta(Tilia._meta(p)) {
  | Value(meta) => {
      let n = Option.getExn(Map.get(meta.observed, "john"))
      t->is(1, Set.size(n.observers))
      Dict.set(p, "john", person())

      let n = Map.get(meta.observed, "john")
      t->is(None, n)
    }
  | _ => t->fail("Meta is undefined")
  }
})

test("Should delete observations on delete", t => {
  let p: people = Dict.make()
  Dict.set(p, "john", person())
  let m = {called: false}
  let p = tilia(p)
  let o = _observe(() => m.called = true)
  let j = Dict.getUnsafe(p, "john")
  t->is(j.name, "John") // o observe 'john.name'
  _ready(o, true)

  switch typeMeta(Tilia._meta(p)) {
  | Value(meta) => {
      let n = Option.getExn(Map.get(meta.observed, "john"))
      t->is(1, Set.size(n.observers))
      Dict.delete(p, "john")

      let n = Map.get(meta.observed, "john")
      t->is(None, n)
    }
  | _ => t->fail("Meta is undefined")
  }
})

type track = {mutable flush: unit => unit}
let flush = (t: track, fn) => t.flush = fn

type familiy = dict<person>

asyncTest("Should work with setTimeout as flush", t => {
  let m = {called: false}
  let r = make(~flush=fn => ignore(setTimeout(fn, 0)))
  let p = r.tilia(person())
  let _ = r.observe(() => {
    t->is(p.name, p.name)
    m.called = true
  })
  m.called = false

  Promise.make((resolve, _) => {
    p.name = "Dunia"
    p.name = "Maria"
    p.name = "Muholi"
    t->isFalse(m.called)
    ignore(
      setTimeout(
        () => {
          t->isTrue(m.called)
          resolve()
        },
        0,
      ),
    )
  })
})

test("Should create computed", t => {
  let p = {name: "John", username: "jo"}
  let p = tilia(p)
  let m = {called: false}
  p.name = computed(() => {
    m.called = true
    p.username ++ " OK"
  })
  // Not called: does not have observers
  t->isFalse(m.called)

  p.username = "mary"
  t->isFalse(m.called)
  // On read, the callback is called
  t->is(p.name, "mary OK")
  t->isTrue(m.called)
})

test("Should set computed for recursive computed in object", t => {
  let m = {called: false}

  // To not reference self in the computed, we need first create
  // the object and then the computed.
  let p = tilia({name: "Milo", username: "milo"})
  p.name = computed(() => {
    m.called = true
    p.username ++ " is OK"
  })

  // Not called: does not have observers
  t->isFalse(m.called)

  // On read, the callback is called
  t->is(p.name, "milo is OK")
  t->isTrue(m.called)
  m.called = false
  t->is(p.name, "milo is OK")
  t->isFalse(m.called)
})

test("Should proxify computed object", t => {
  let m = {called: false}
  let x = tilia(person())
  let p = tilia({
    name: "Louise",
    address: computed(() => {
      m.called = true
      {city: "Wild " ++ x.name, zip: 1234}
    }),
    phone: Value("827013"),
    other_address: {city: "Angels", zip: 1234},
    passions: [],
    notes: TestObject.make(),
  })
  t->isFalse(m.called)
  let mo = {called: false}
  let o = _observe(() => mo.called = true)
  t->is(p.address.city, "Wild John")
  _ready(o, true)
  t->isTrue(m.called)
  m.called = false
  t->isFalse(mo.called)
  x.name = "Mary"
  t->isTrue(m.called)
  t->isTrue(mo.called)
})

test("Should not notify if unchanged computed", t => {
  let p = {name: "John", username: "jo"}
  let p = tilia(p)
  let mo = {called: false}
  observe(() => {
    t->is(p.name, p.name) // Read p.name
    mo.called = true
  })
  t->isTrue(mo.called)
  mo.called = false

  // Replacing a raw value with a computed with the same value should not
  // trigger a notification.
  let mc = {called: false}
  p.name = computed(() => {
    t->is(p.username, p.username)
    mc.called = true
    p.name
  })
  // Computed called (because it has observers)
  t->isTrue(mc.called)
  mc.called = false

  // Observer not called because value did not change
  t->isFalse(mo.called)

  // Compute called
  p.username = "mary"
  t->isTrue(mc.called)
  // Value did not change: not notified
  t->isFalse(mo.called)
})

test("Should clear compute on deleting key", t => {
  let p = {name: "John", username: "jo"}
  let p = tilia(p)
  let m = {called: false}
  p.name = computed(() => {
    m.called = true
    p.username ++ " OK"
  })
  t->isFalse(m.called)
  AnyObject.deleteProperty(p, "name")

  p.username = "mary"
  t->isFalse(m.called)
  t->is(p.name, %raw(`undefined`))
  t->isFalse(m.called)
})

test("Should clear compute on replacing compute", t => {
  let p = {name: "John", username: "jo"}
  let p = tilia(p)
  let m = {called: false}
  p.name = computed(() => {
    m.called = true
    p.username ++ " is nice"
  })
  // Trigger first compute (and observations)
  t->is(p.name, "jo is nice")
  t->isTrue(m.called)
  m.called = false

  p.name = computed(() => p.username ++ " is beautiful")

  p.username = "Lisa"
  t->is(p.name, "Lisa is beautiful")
  t->isFalse(m.called)
})

test("Compute should notify cache observer on dependency change", t => {
  let p = {name: "John", username: "jo"}
  let p = tilia(p)
  let mo = {called: false}
  let read = ref(true)
  observe(() => {
    if read.contents {
      t->is(p.name, p.name) // Read value from proxy
    }
    mo.called = true
  })
  mo.called = false

  let mc = {called: false}
  p.name = computed(() => {
    t->is(p.username, p.username) // Just to read value from proxy
    mc.called = true
    "Loading"
  })
  // On compute setup, observers are notified (because it is like a value
  // change).
  t->isTrue(mo.called)
  t->isTrue(mc.called)
  mo.called = false
  mc.called = false
  read.contents = false

  p.username = "mary"
  // There are observers, value computed even though it might not be read.
  t->isFalse(mo.called)
  t->isTrue(mc.called)
})

test("Compute should work with observers", t => {
  let p = {name: "John", username: "jo"}
  let p = tilia(p)
  p.name = computed(() => {
    p.username ++ " is OK"
  })
  let name = ref("")
  observe(() => {
    name.contents = p.name
  })
  t->is(name.contents, "jo is OK")

  p.username = "mary"
  t->is(name.contents, "mary is OK")
})

test("Computed should behave like a value", t => {
  let p = {name: "John", username: "jo"}
  let p = tilia(p)
  p.name = computed(() => p.username ++ " is OK")
  let name = ref("")
  observe(() => {
    name.contents = p.name
  })
  t->is(name.contents, "jo is OK")

  p.username = "mary"
  t->is(name.contents, "mary is OK")
})

test("Should share tracking within the same forest", t => {
  let m = {called: false}
  let p1 = tilia(person())
  let p2 = tilia(person())
  let o = _observe(() => m.called = true)
  t->is(p1.address.city, "Truth") // observe 'city'
  _ready(o, true)
  t->isFalse(m.called)

  // Shares the same target, and the same proxy root
  p2.other_address = p1.address
  p2.other_address.city = "Love"
  // Should call observer on p1
  t->isTrue(m.called)
  // The value changed without proxy call (target is the same).
  t->is(p1.address.city, "Love")
  p1.address.city = "Life"
  t->isTrue(m.called)
})

test("Should share computed between trees", t => {
  let mo = {called: false}
  let src = tilia(person())
  src.name = "Nila"
  let mt = {called: false}
  let trg = tilia({
    name: computed(() => {
      mt.called = true
      src.name
    }),
    username: "nil",
  })

  // Here it does not matter if we use p2 or p1, because it will connect
  // to the same root in any case.
  let o = _observe(() => mo.called = true)
  t->is(trg.name, "Nila") // observe p2.name
  t->isTrue(mt.called) // To get "Nila" in the computed
  mt.called = false
  _ready(o, true)

  t->isFalse(mo.called)

  src.name = "Alina"
  // Should call observer of p2
  t->isTrue(mo.called)
  // Already called because there is an observer and we notify after rebuild
  t->isTrue(mt.called)
  t->is(trg.name, "Alina")
})

test("Returned object from a computed should be a proxy", t => {
  let p = tilia(person())

  let m = {called: false}
  p.address = computed(() => {
    zip: 0,
    city: "Kernel",
  })
  t->notThrows(() => {
    let o = _observe(() => m.called = true)
    t->is(p.address.city, "Kernel")
    _ready(o, true)
  })
  p.address.city = "Image"
  t->isTrue(m.called)
})

type dateo = {date: Js.Date.t}

test("Should not proxify class instance", t => {
  let p = tilia({date: Js.Date.make()})
  t->isTrue(%raw(`p.date instanceof Date`))
  t->is(Tilia._meta(p.date), undefined)
  t->is(p.date->Js.Date.getMilliseconds, %raw(`p.date.getMilliseconds()`))
})

type machine = Blank | Loading | Loaded

type auth = NotAuthenticated | Authenticating | Authenticated

test("Should allow state machines in observed", t => {
  let (p, set) = signal(Blank)
  let (auth, setAuth) = signal(NotAuthenticated)
  observe(() => {
    switch (p.value, auth.value) {
    | (Blank, Authenticating) => set(Loading)
    | (Loading, Authenticated) => set(Loaded)
    | (Loaded, NotAuthenticated) => set(Blank)
    | _ => ()
    }
  })

  t->deepEqual(p.value, Blank)

  // Update dependency
  setAuth(Authenticating)
  t->is(p.value, Loading)

  // Update dependency
  setAuth(Authenticated)
  t->is(p.value, Loaded)

  setAuth(NotAuthenticated)
  t->is(p.value, Blank)
})

type enter<'a> = {mutable enter: 'a => unit}

let sleep: unit => promise<unit> = async () =>
  %raw(`new Promise(resolve => setTimeout(resolve, 10))`)

test("should not trigger on setting the same proxied object", t => {
  let p = tilia(person())
  let m = {called: false}
  observe(() => {
    t->is(p.address.city, "Truth") // observe 'address.city'
    m.called = true
  })
  m.called = false
  p.address = p.address
  t->isFalse(m.called)
})

test("should not trigger on setting the same target object", t => {
  let q = person()
  let p = tilia(q)
  let m = {called: false}
  observe(() => {
    t->is(p.address.city, "Truth") // observe 'address.city'
    m.called = true
  })
  m.called = false

  // Same target object
  p.address = q.address
  t->isFalse(m.called)
})

test("should not trigger observer while in a callback", t => {
  let p = tilia(person())
  let m = {called: false}
  observe(() => {
    // observe 'p.address.city'
    t->is(p.address.city, p.address.city)
    m.called = true
  })
  m.called = false

  observe(() => {
    t->isFalse(m.called)
    p.address.city = "Beauty"
    t->isFalse(m.called)
  })
  t->isTrue(m.called)
})

test("Should disable computed on replace", t => {
  let p1 = tilia({name: "Diana", username: "diana"})
  let p = tilia(person())
  p.name = computed(() => p1.name)
  t->is("Diana", p.name)
  p.name = "Lisa"
  p1.name = "Anabel"
  // Did not update through computed
  t->is("Lisa", p.name)
})

test("Should allow replacing computed", t => {
  let p1 = tilia({name: "Diana", username: "diana"})
  let p = tilia(person())
  p.name = computed(() => p1.name)
  t->is("Diana", p.name)
  p.name = computed(() => p1.username)
  t->is("diana", p.name)
  p1.name = "Anabel"
  // Did not update through old computed
  t->is("diana", p.name)
})

// ================ EXTRA ================

test("Should create signal", t => {
  let q = {name: "Linda", username: "linda"}
  let p2 = person()

  let (p, set) = signal({name: "Noether", username: "emmy"})

  observe(() => {
    p2.name = p.value.name
  })
  t->is("Noether", p2.name)
  set(q)
  t->is("Linda", p2.name)
})

type loading = {loaded: user => unit}

type ready = {
  user: user,
  logout: unit => unit,
}
type loggedOut = {loading: unit => unit}

type state =
  | Loading(loading)
  | Ready(ready)
  | LoggedOut(loggedOut)

test("Should manage store", t => {
  let rec ready = (set: state => unit, user) => Ready({user, logout: () => set(loggedOut(set))})
  and loggedOut = (set: state => unit) => LoggedOut({loading: () => set(loading(set))})
  and loading = (set: state => unit) => Loading({loaded: user => set(ready(set, user))})

  let p = store(loggedOut)

  switch p.value {
  | LoggedOut(app) => app.loading()
  | _ => t->fail("Not logged out")
  }

  switch p.value {
  | Loading(app) => app.loaded({name: "Alice", username: "alice"})
  | _ => t->fail("Not loading")
  }

  switch p.value {
  | Ready(app) => app.logout()
  | _ => t->fail("Not ready")
  }

  switch p.value {
  | LoggedOut(_) => t->pass
  | _ => t->fail("Not logged out")
  }
})

// This is needed to replace a computed with a regular value, from
// inside the computed.
test("Should use store as computed", t => {
  let m = {called: false}
  let p1 = tilia(person())
  let p = store(_ => {
    m.called = true
    // This should be used only once.
    p1.name
  })
  t->isFalse(m.called)
  t->is(p.value, "John")
  t->isTrue(m.called)
  m.called = false
  p1.name = "Lisa"
  t->is(p.value, "John")
  t->isFalse(m.called)
})

test("should work with computed in computed", t => {
  let m = {called: false}
  let p1 = tilia(person())
  let p2 = tilia({
    name: computed(() => {
      m.called = true
      p1.name ++ " p2"
    }),
    username: "foo",
  })
  let p3 = tilia({
    name: computed(() => p2.name ++ " p3"),
    username: "foo",
  })
  t->is("John p2 p3", p3.name)
  m.called = false
  p1.name = "Kyle"
  p1.name = "Nana"
  t->isTrue(m.called)
  t->is("Nana p2 p3", p3.name)
})

test("should trigger if changed after cleared", t => {
  let m = {called: false}
  let (data, set) = signal("Dana")
  // Observer 1 watches the data
  let o1 = _observe(() => m.called = true)
  t->is("Dana", data.value)
  m.called = false

  // Observer 2 watches, and clears which clears the watchers list
  let o2 = _observe(() => ())
  t->is("Dana", data.value)
  _ready(o2, true)
  _clear(o2) // Clears the watchers list

  // Change the data, but nobody is watching it because
  // the watchers list was cleared.
  set("Lala")

  // Would see Cleared without gc
  _ready(o1, true)
  t->isTrue(m.called)
  t->is("Lala", data.value)
})

test("should not trigger if unchanged after cleared", t => {
  // Using a long GC, will not trigger

  let m = {called: false}
  let (data, _) = signal("Dana")
  // Observer 1 will watch the data
  let o1 = _observe(() => m.called = true)
  t->is("Dana", data.value)
  m.called = false

  // Observer 2 watches, and clears which clears the watchers list
  let o2 = _observe(() => ())
  t->is("Dana", data.value)
  _ready(o2, true)
  _clear(o2) // Clears the watchers list

  // Would trigger right away without gc
  _ready(o1, true)
  // Did not trigger because the gc protected Clearing.
  t->isFalse(m.called)
})

test("should trigger with very short gc", t => {
  let ctx = make(~gc=0)
  let signal = ctx.signal
  let _observe = ctx._observe
  let _ready = ctx._ready
  let _clear = ctx._clear

  let m = {called: false}
  let (data, _) = signal("Dana")
  let (data2, _) = signal("Dana")
  // Observer 1 will watch the data
  let o1 = _observe(() => m.called = true)
  t->is("Dana", data.value)
  m.called = false

  // Observer 2 watches, and clears which clears the watchers list
  let o2 = _observe(() => ())
  t->is("Dana", data.value)
  _ready(o2, true)
  _clear(o2) // Clears the watchers list

  for _ in 1 to 2 {
    // To make the GC advance
    let o2 = _observe(() => ())
    t->is("Dana", data2.value)
    _ready(o2, true)
    _clear(o2) // Clears the watchers list
  }

  // Would trigger right away without gc
  _ready(o1, true)
  // Should not trigger because the value is unchanged.
  t->isTrue(m.called)
})

test("should stop observing after _done", t => {
  let m = {called: false}
  let p = tilia(person())
  let o = _observe(() => m.called = true)
  t->is("John", p.name)
  _done(o)
  t->is("Truth", p.address.city)
  _ready(o, true)
  t->isFalse(m.called)
  p.address.city = "Irpin"
  t->isFalse(m.called)
  p.name = "Paulina"
  t->isTrue(m.called)
})
