open Ava
open Assert
module Core = TiliaCore
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

test("Should track leaf changes", t => {
  let m = {called: false}
  let p = {name: "John", username: "jo"}
  let x = Core.make(p)
  let o = Core._connect(x, () => m.called = true)
  t->is(x.name, "John") // observe 'name'
  t->is(m.called, false)
  Core._flush(o)

  // Update name with same value after flush
  x.name = "John"
  // Callback should not be called
  t->is(m.called, false)

  // Update name with another value after flush
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
  let p = Core.make(p)
  Core.observe(p, p => {
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
  let p = Core.make(p)
  Core.observe(p, p => {
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
  let p = Core.make(p)
  Core.observe(p, p => {
    if p.username === "john" {
      // This makes 'username' dead...Will not be observed.
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
  let p = Core.make(p)
  let o = Core._connect(p, () => m.called = true)
  t->is(p.address.city, "Truth") // observe 'address.city'
  t->is(m.called, false)
  Core._flush(o)

  // Update name with same value after flush
  p.address.city = "Truth"
  // Callback should not be called
  t->is(m.called, false)

  // Update name with another value after flush
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
  let p = Core.make(p)
  let o = Core._connect(p, () => m.called = true)
  t->is(p.passions[0], Some("fruits")) // observe key 0
  Core._flush(o)

  // Update entry
  p.passions[0] = "watercolor"
  // Callback should be called
  t->is(m.called, true)
})

test("Should watch array index", t => {
  let m = {called: false}
  let p = person()
  let p = Core.make(p)
  let o = Core._connect(p, () => m.called = true)
  t->is(Array.length(p.passions), 1) // observe length
  Core._flush(o)

  // Insert new entry
  Array.push(p.passions, "watercolor")
  // Callback should be called
  t->is(m.called, true)
})

test("Should watch object keys", t => {
  let m = {called: false}
  let p = person()
  let p = Core.make(p)
  let o = Core._connect(p, () => m.called = true)
  t->is(Array.length(TestObject.keys(p.notes)), 0) // observe keys
  Core._flush(o)

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
  let p = Core.make(p)
  let o = Core._connect(p, () => m.called = true)
  t->is(Array.length(TestObject.keys(p.notes)), 2) // observe keys
  Core._flush(o)

  // Insert new entry
  TestObject.set(p.notes, "night", "Full of stars")
  // Callback should not be called
  t->is(m.called, false)
})

test("Should throw on connect to non tilia object", t => {
  let error = {message: None}
  try {
    ignore(Core._connect({name: "Not a tree", username: "Ho"}, () => ()))
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
  let p = Core.make(p)
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
  let p = Core.make(p)
  let o = Core._connect(p, () => m.called = true)
  t->is(p.address.city, "Truth") // observe 'city'
  Core._flush(o)
  t->isFalse(m.called)
  p.other_address = p.address
  p.other_address.city = "Love"
  // Should share the same proxy branch
  t->isTrue(p.address === p.other_address)

  t->isTrue(m.called)
})

test("Should not share tracking in another tree", t => {
  let m = {called: false}
  let p1 = Core.make(person())
  let p2 = Core.make(person())
  let o = Core._connect(p1, () => m.called = true)
  t->is(p1.address.city, "Truth") // observe 'city'
  Core._flush(o)
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
  let p = Core.make(person())
  TestObject.set(p.notes, "hello", "Everyone")
  let o = Core._connect(p, () => m.called = true)
  t->is(TestObject.get(p.notes, "hello"), "Everyone") // observe "hello" key
  Core._flush(o)

  // Remove entry
  TestObject.remove(p.notes, "hello")
  // Callback should be called
  t->is(m.called, true)
})

test("Should not proxy or watch prototype methods", t => {
  let m = {called: false}
  let p = Core.make(person())
  let o = Core._connect(p, () => m.called = true)
  let x = TestObject.get(p.notes, "constructor")
  t->isTrue(x === TestObject.get(%raw(`{}`), "constructor"))
  Core._flush(o)

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
  let tree = Core.make(tree)
  let o = Core._connect(tree, () => m.called = true)
  let p2 = AnyObject.get(tree, "person")
  t->isTrue(p2 === p1)
  Core._flush(o)

  // Cannot set
  t->isFalse(AnyObject.set(tree, "person", person()))

  // Callback should not be called
  t->is(m.called, false)

  // Exact original value is always returned
  t->isTrue(AnyObject.get(tree, "person") === p1)
})

test("Should track undefined values", t => {
  let m = {called: false}
  let p = person()
  let p = Core.make(p)
  let o = Core._connect(p, () => m.called = true)
  let phone = p.phone
  t->isTrue(phone === Undefined)
  Core._flush(o)

  p.phone = Value("123 456 789")
  // Callback should be called
  t->is(m.called, true)
})

test("Should notify on flush", t => {
  let m = {called: false}
  let p = person()
  let p = Core.make(p)
  let o = Core._connect(p, () => m.called = true)
  t->is(p.name, "John") // observe 'name'
  t->is(m.called, false)

  // Update name before flush
  p.name = "One"
  // Callback should not be called
  t->is(m.called, false)
  Core._flush(o)
  // Callback should be called during flush
  t->is(m.called, true)
})
