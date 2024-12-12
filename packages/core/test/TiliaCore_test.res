open Ava
open Assert
module Core = TiliaCore
module Object = {
  type t
  let make: unit => t = %raw(`() => ({})`)
  external get: (t, string) => string = "Reflect.get"
  external set: (t, string, string) => unit = "Reflect.set"
  external keys: t => array<string> = "Object.keys"
}

type user = {mutable name: string, mutable username: string}
type address = {mutable city: string, mutable zip: int}
type person = {
  mutable name: string,
  mutable address: address,
  mutable passions: array<string>,
  mutable notes: Object.t,
}
type tester = {mutable called: bool}

test("Should track leaf changes", t => {
  let m = {called: false}
  let p = {name: "John", username: "jo"}
  let x = Core.make(p)
  let o = Core._connect(x, () => m.called = true)
  t->is(x.name, "John") // observe 'name'
  t->is(m.called, false)

  // Update name before flush
  x.name = "One"
  // Callback Should not be called
  t->is(m.called, false)
  Core._flush(o)

  // Update name with same value after flush
  x.name = "One"
  // Callback Should not be called
  t->is(m.called, false)

  // Update name with another value after flush
  x.name = "Two"
  // Callback Should be called
  t->is(m.called, true)
  m.called = false

  // Update again
  x.name = "Three"
  // Callback Should not be called
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

test("Should allow mutating observed", t => {
  let p = {name: "John", username: "jo"}
  let p = Core.make(p)
  Core.observe(p, p => {
    open String
    p.name = p.name->toLowerCase->slice(~start=0, ~end=2)
  })

  t->is(p.name, "jo")

  // Update with same name
  p.name = "John"
  // Observing callback not called
  t->is(p.name, "jo")

  // Update with another name
  p.name = "Mary"
  // Observing callback called
  t->is(p.name, "ma")
})

test("Should proxy sub-objects", t => {
  let m = {called: false}
  let p = {
    name: "John",
    address: {
      city: "Love",
      zip: 1234,
    },
    passions: [],
    notes: Object.make(),
  }
  let p = Core.make(p)
  let o = Core._connect(p, () => m.called = true)
  t->is(p.address.city, "Love") // observe 'address.city'
  t->is(m.called, false)

  // Update name before flush
  p.address.city = "Passion"
  // Callback Should not be called
  t->is(m.called, false)
  Core._flush(o)

  // Update name with same value after flush
  p.address.city = "Passion"
  // Callback Should not be called
  t->is(m.called, false)

  // Update name with another value after flush
  p.address.city = "Kindness"
  // Callback Should be called
  t->is(m.called, true)
  m.called = false

  // Update again
  p.address.city = "Sorrow"
  // Callback Should not be called
  t->is(m.called, false)
})

test("Should proxy array", t => {
  let m = {called: false}
  let p = {
    name: "John",
    address: {
      city: "Love",
      zip: 1234,
    },
    passions: ["fruits"],
    notes: Object.make(),
  }
  let p = Core.make(p)
  let o = Core._connect(p, () => m.called = true)
  t->is(p.passions[0], Some("fruits")) // observe key 0
  Core._flush(o)

  // Update entry
  p.passions[0] = "watercolor"
  // Callback Should be called
  t->is(m.called, true)
})

test("Should watch array index", t => {
  let m = {called: false}
  let p = {
    name: "John",
    address: {
      city: "Love",
      zip: 1234,
    },
    passions: ["fruits"],
    notes: Object.make(),
  }
  let p = Core.make(p)
  let o = Core._connect(p, () => m.called = true)
  t->is(Array.length(p.passions), 1) // observe length
  Core._flush(o)

  // Insert new entry
  Array.push(p.passions, "watercolor")
  // Callback Should be called
  t->is(m.called, true)
})

test("Should watch object keys", t => {
  let m = {called: false}
  let p = {
    name: "John",
    address: {
      city: "Love",
      zip: 1234,
    },
    passions: ["fruits"],
    notes: Object.make(),
  }
  let p = Core.make(p)
  let o = Core._connect(p, () => m.called = true)
  t->is(Array.length(Object.keys(p.notes)), 0) // observe keys
  Core._flush(o)

  // Insert new entry
  Object.set(p.notes, "2024-12-07", "Rebuilding Tilia in ReScript")
  // Callback Should be called
  t->is(m.called, true)
})

test("Should throw on connect to non tilia object", t => {
  try {
    ignore(Core._connect({name: "Not a tree", username: "Ho"}, () => ()))
  } catch {
  | Exn.Error(obj) => t->is(obj->Exn.message, Some("Observed state is not a tilia proxy."))
  }
})
