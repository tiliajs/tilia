open Ava
let onot = not
module OSkip = Skip
open Assert
let not = onot
module Skip = OSkip

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

// Default context
let r = Tilia.tilia(~flush=apply)
let connect = Tilia.connect
let computed = Tilia.computed

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
  let p = {name: "John", username: "jo"}
  let x = connect(r, p)
  let o = Tilia._connect(x, () => m.called = true)
  t->is(x.name, "John") // observe 'name'
  t->is(m.called, false)
  Tilia._ready(o)

  // Update name with same value after ready
  x.name = "John"
  // Callback should not be called
  t->is(m.called, false)

  // Update name with another value after ready
  x.name = "Mary"
  // Callback should be called
  t->is(m.called, true)
  m.called = false

  // Update again
  x.name = "Three"
  // Callback should not be called
  t->is(m.called, false)
})

test("Should observe", t => {
  let p = {name: "John", username: "jo"}
  let p = connect(r, p)
  Tilia.observe(p, p => {
    open String
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
  let p = connect(r, p)
  Tilia.observe(p, p => {
    p.name = p.name ++ " OK"
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
  let p = connect(r, p)
  Tilia.observe(p, p => {
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
  let p = connect(r, p)
  let o = Tilia._connect(p, () => m.called = true)
  t->is(p.address.city, "Truth") // observe 'address.city'
  t->is(m.called, false)
  Tilia._ready(o)

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
  let p = connect(r, p)
  let o = Tilia._connect(p, () => m.called = true)
  t->is(p.passions[0], Some("fruits")) // observe key 0
  Tilia._ready(o)

  // Update entry
  p.passions[0] = "watercolor"
  // Callback should be called
  t->is(m.called, true)
})

test("Should watch array index", t => {
  let m = {called: false}
  let p = person()
  let p = connect(r, p)
  let o = Tilia._connect(p, () => m.called = true)
  t->is(Array.length(p.passions), 1) // observe length
  Tilia._ready(o)

  // Insert new entry
  Array.push(p.passions, "watercolor")
  // Callback should be called
  t->is(m.called, true)
})

test("Should watch object keys", t => {
  let m = {called: false}
  let p = person()
  let p = connect(r, p)
  let o = Tilia._connect(p, () => m.called = true)
  t->is(Array.length(TestObject.keys(p.notes)), 0) // observe keys
  Tilia._ready(o)

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
  let p = connect(r, p)
  let o = Tilia._connect(p, () => m.called = true)
  t->is(Array.length(TestObject.keys(p.notes)), 2) // observe keys
  Tilia._ready(o)

  // Insert new entry
  TestObject.set(p.notes, "night", "Full of stars")
  // Callback should not be called
  t->is(m.called, false)
})

test("Should throw on connect to non tilia object", t => {
  let error = {message: None}
  try {
    ignore(Tilia._connect({name: "Not a tree", username: "Ho"}, () => ()))
    error.message = Some("Did not throw")
  } catch {
  | Exn.Error(err) => error.message = Exn.message(err)
  }
  t->is(error.message, Some("Observed state is not a tilia proxy."))
})

test("Should not clone added objects", t => {
  let p = person()
  let a = {
    city: "Storm",
    zip: 9999,
  }
  let p = connect(r, p)
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
  let p = connect(r, p)
  let o = Tilia._connect(p, () => m.called = true)
  t->is(p.address.city, "Truth") // observe 'city'
  Tilia._ready(o)
  t->isFalse(m.called)
  p.other_address = p.address
  p.other_address.city = "Love"
  // Should share the same proxy branch
  t->isTrue(p.address === p.other_address)

  t->isTrue(m.called)
})

test("Should not share tracking in another forest", t => {
  let m = {called: false}
  let r1 = Tilia.tilia()
  let r2 = Tilia.tilia()
  let p1 = connect(r1, person())
  let p2 = connect(r2, person())
  let o = Tilia._connect(p1, () => m.called = true)
  t->is(p1.address.city, "Truth") // observe 'city'
  Tilia._ready(o)
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
  let p = connect(r, person())
  TestObject.set(p.notes, "hello", "Everyone")
  let o = Tilia._connect(p, () => m.called = true)
  t->is(TestObject.get(p.notes, "hello"), "Everyone") // observe "hello" key
  Tilia._ready(o)

  // Remove entry
  TestObject.remove(p.notes, "hello")
  // Callback should be called
  t->is(m.called, true)
})

test("Should not proxy or watch prototype methods", t => {
  let m = {called: false}
  let p = connect(r, person())
  let o = Tilia._connect(p, () => m.called = true)
  let x = TestObject.get(p.notes, "constructor")
  t->isTrue(x === TestObject.get(%raw(`{}`), "constructor"))
  Tilia._ready(o)

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
  let tree = connect(r, tree)
  let o = Tilia._connect(tree, () => m.called = true)
  let p2 = AnyObject.get(tree, "person")
  t->isTrue(p2 === p1)
  Tilia._ready(o)

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
  let p = connect(r, p)
  let o = Tilia._connect(p, () => m.called = true)
  let phone = p.phone
  t->isTrue(phone === Undefined)
  Tilia._ready(o)

  p.phone = Value("123 456 789")
  // Callback should be called
  t->is(m.called, true)
})

test("Should notify if update before ready", t => {
  let m = {called: false}
  let p = person()
  let p = connect(r, p)
  let o = Tilia._connect(p, () => m.called = true)
  t->is(p.name, "John") // observe 'name'
  t->is(m.called, false)

  // Update name before ready
  p.name = "One"
  // Callback should not be called
  t->is(m.called, false)
  Tilia._ready(o)
  // Callback should be called during ready
  t->is(m.called, true)
})

test("Should notify on many updates before ready", t => {
  let m = {called: false}
  let p = person()
  let p = connect(r, p)
  let o = Tilia._connect(p, () => m.called = true)
  t->is(p.name, "John") // observe 'name'
  t->is(m.called, false)

  Tilia._ready(o)
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
  let p = connect(r, p)
  let o1 = Tilia._connect(p, () => m1.called = true)
  t->is(p.name, "John") // o1 observe 'name'
  let o2 = Tilia._connect(p, () => m2.called = true)
  t->is(p.name, "John") // o2 observe 'name'
  Tilia._ready(o1) // o1 register, o2 not registered
  Tilia.clear(o1) // removes watchers (set empty)
  Tilia._ready(o2)
  t->is(m2.called, false)

  // Update 'name'
  p.name = "Mary"
  // Callback should be called
  t->is(m2.called, true)
})

test("Should support ready, clear, ready", t => {
  let m = {called: false}
  let p = person()
  let p = connect(r, p)
  let o = Tilia._connect(p, () => m.called = true)
  t->is(p.name, "John") // o observe 'name'
  Tilia._ready(o)
  Tilia.clear(o)
  Tilia._ready(o)
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
  let items = connect(
    r,
    {
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
    },
  )
  Tilia.observe(items, _ => {
    items.sorted = [...items.all]
    Array.sort(items.sorted, (a, b) => String.compare(a.name, b.name))
  })
  let o = Tilia._connect(items, () => m.called = true)
  t->is(getExn(items.sorted[2]).name, "carrot") // o observe [2] and [2].name
  Tilia._ready(o)
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

let getMeta: Tilia.meta<'a> => meta<'a> = _m => %raw(`_m`)

test("Should get internals with _meta", t => {
  let person = {
    name: "Mary",
    username: "mama78",
    address: {city: "Los Angleless", zip: 1234},
  }
  let p = connect(r, person)
  Tilia.observe(p, p => {
    p.username = p.name
    p.username = p.address.city
  })
  let o = Tilia._connect(p, _ => ())
  t->is("Los Angleless", p.address.city)
  Tilia._ready(o)

  let meta = getMeta(Tilia._meta(p))
  t->is(person, meta.target)
  let n = Option.getExn(Map.get(meta.observed, "name"))
  t->is(1, Set.size(n.observers))

  let address = Option.getExn(Map.get(meta.proxied, "address")).proxy
  t->is(p.address, address)

  let meta = getMeta(Tilia._meta(address))
  t->is(person.address, meta.target)

  let n = Option.getExn(Map.get(meta.observed, "city"))
  t->is(2, Set.size(n.observers))
})

test("Should clear if ready never called", t => {
  let m = {called: false}
  let p = person()
  let p = connect(r, p)
  let _ = Tilia._connect(p, () => m.called = true)
  t->is(p.name, "John") // o observe 'name'

  // Ready never called
  // Observers should be zero
  let meta = getMeta(Tilia._meta(p))
  let n = Option.getExn(Map.get(meta.observed, "name"))
  t->is(0, Set.size(n.observers))
})

type people = dict<person>

test("Should delete observations on set", t => {
  let p: people = Dict.make()
  Dict.set(p, "john", person())
  let m = {called: false}
  let p = connect(r, p)
  let o = Tilia._connect(p, () => m.called = true)
  let j = Dict.getUnsafe(p, "john")
  t->is(j.name, "John") // o observe 'john.name'
  Tilia._ready(o)

  let meta = getMeta(Tilia._meta(p))
  let n = Option.getExn(Map.get(meta.observed, "john"))
  t->is(1, Set.size(n.observers))
  Dict.set(p, "john", person())

  let n = Map.get(meta.observed, "john")
  t->is(None, n)
})

test("Should delete observations on delete", t => {
  let p: people = Dict.make()
  Dict.set(p, "john", person())
  let m = {called: false}
  let p = connect(r, p)
  let o = Tilia._connect(p, () => m.called = true)
  let j = Dict.getUnsafe(p, "john")
  t->is(j.name, "John") // o observe 'john.name'
  Tilia._ready(o)

  let meta = getMeta(Tilia._meta(p))
  let n = Option.getExn(Map.get(meta.observed, "john"))
  t->is(1, Set.size(n.observers))
  Dict.delete(p, "john")

  let n = Map.get(meta.observed, "john")
  t->is(None, n)
})

type track = {mutable flush: unit => unit}
let flush = (t: track, fn) => t.flush = fn

type familiy = dict<person>

Skip.asyncTest("Should use setTimeout as default flush", t => {
  let m = {called: false}
  let r = Tilia.tilia()
  let p = connect(r, person())
  let _ = Tilia.observe(p, _ => {
    t->is(p.name, p.name)
    m.called = true
  })

  Promise.make((resolve, _) => {
    m.called = false
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
  let p = connect(r, p)
  let m = {called: false}
  p.name = computed("John", p => {
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

test("Should manage computed in object", t => {
  let m = {called: false}
  let p = {
    name: computed("John", p => {
      m.called = true
      p.username ++ " is OK"
    }),
    username: "jo",
  }
  let p = connect(r, p)
  // Not called: does not have observers
  t->isFalse(m.called)

  // On read, the callback is called
  t->is(p.name, "jo is OK")
  t->isTrue(m.called)
  m.called = false
  t->is(p.name, "jo is OK")
  t->isFalse(m.called)
})

test("Should proxify computed object", t => {
  let m = {called: false}
  let p = connect(
    r,
    {
      name: "Louise",
      address: computed({city: "Any", zip: 1234}, p => {
        m.called = true
        {city: "Wild " ++ p.name, zip: 1234}
      }),
      phone: Value("827013"),
      other_address: {city: "Angels", zip: 1234},
      passions: [],
      notes: TestObject.make(),
    },
  )
  t->isFalse(m.called)
  let mo = {called: false}
  let o = Tilia._connect(p, () => mo.called = true)
  t->is(p.address.city, "Wild Louise")
  Tilia._ready(o)
  t->isTrue(m.called)
  m.called = false
  t->isFalse(mo.called)
  p.name = "Mary"
  t->isTrue(m.called)
  t->isTrue(mo.called)
})

test("Should not notify if unchanged computed", t => {
  let p = {name: "John", username: "jo"}
  let p = connect(r, p)
  let mo = {called: false}
  Tilia.observe(p, p => {
    t->is(p.name, p.name) // Read p.name
    mo.called = true
  })
  t->isTrue(mo.called)
  mo.called = false

  // Replacing a raw value with a computed with the same value should not
  // trigger a notification.
  let mc = {called: false}
  p.name = computed(p.name, p => {
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
  let p = connect(r, p)
  let m = {called: false}
  p.name = computed("", p => {
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
  let p = connect(r, p)
  let m = {called: false}
  p.name = computed("", p => {
    m.called = true
    p.username ++ " is nice"
  })
  // Trigger first compute (and observations)
  t->is(p.name, "jo is nice")
  t->isTrue(m.called)
  m.called = false

  p.name = computed("", p => p.username ++ " is beautiful")

  p.username = "Lisa"
  t->is(p.name, "Lisa is beautiful")
  t->isFalse(m.called)
})

test("Compute should notify cache observer on dependency change", t => {
  let p = {name: "John", username: "jo"}
  let p = connect(r, p)
  let mo = {called: false}
  let read = ref(true)
  Tilia.observe(p, p => {
    if read.contents {
      t->is(p.name, p.name) // Read value from proxy
    }
    mo.called = true
  })
  mo.called = false

  let mc = {called: false}
  p.name = computed("", p => {
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
  let p = connect(r, p)
  p.name = computed("", p => {
    p.username ++ " is OK"
  })
  let name = ref("")
  Tilia.observe(p, p => {
    name.contents = p.name
  })
  t->is(name.contents, "jo is OK")

  p.username = "mary"
  t->is(name.contents, "mary is OK")
})

test("Computed should behave like a defined compute", t => {
  let p = {name: "John", username: "jo"}
  let p = connect(r, p)
  p.name = Tilia.computed("", () => p.username ++ " is OK")
  let name = ref("")
  Tilia.observe(p, p => {
    name.contents = p.name
  })
  t->is(name.contents, "jo is OK")

  p.username = "mary"
  t->is(name.contents, "mary is OK")
})

test("Should share tracking within the same forest", t => {
  let m = {called: false}
  let p1 = connect(r, person())
  let p2 = connect(r, person())
  let o = Tilia._connect(p1, () => m.called = true)
  t->is(p1.address.city, "Truth") // observe 'city'
  Tilia._ready(o)
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
  let src = connect(r, person())
  src.name = "Nila"
  let mt = {called: false}
  let trg = connect(
    r,
    {
      name: computed("", () => {
        mt.called = true
        src.name
      }),
      username: "nil",
    },
  )

  // Here it does not matter if we use p2 or p1, because it will connect
  // to the same root in any case.
  let o = Tilia._connect(trg, () => mo.called = true)
  t->is(trg.name, "Nila") // observe p2.name
  t->isTrue(mt.called) // To get "Nila" in the computed
  mt.called = false
  Tilia._ready(o)

  t->isFalse(mo.called)

  src.name = "Alina"
  // Should call observer of p2
  t->isTrue(mo.called)
  // Already called because there is an observer and we notify after rebuild
  t->isTrue(mt.called)
  t->is(trg.name, "Alina")
})
