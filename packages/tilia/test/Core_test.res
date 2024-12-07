open Ava
open Assert
type user = {mutable name: string, mutable username: string}
type address = {mutable city: string, mutable zip: int}
type person = {
  mutable name: string,
  mutable address: address,
}
type tester = {mutable called: bool}

test("should track leaf changes", t => {
  let m = {called: false}
  let p = {name: "John", username: "jo"}
  let r = Core.make(p)
  let (_, x) = r
  let o = Core._connect(r, () => m.called = true)
  t->is(x.name, "John") // observe 'name'
  t->is(m.called, false)

  // Update name before flush
  x.name = "One"
  // Callback should not be called
  t->is(m.called, false)
  Core._flush(o)

  // Update name with same value after flush
  x.name = "One"
  // Callback should be called
  t->is(m.called, false)

  // Update name with another value after flush
  x.name = "Two"
  // Callback should be called
  t->is(m.called, true)
  m.called = false

  // Update again
  x.name = "Three"
  // Callback should not be called
  t->is(m.called, false)
})

test("should observe", t => {
  let p = {name: "John", username: "jo"}
  let r = Core.make(p)
  Core.observe(r, p => {
    open String
    p.username = p.name->toLowerCase->slice(~start=0, ~end=2)
  })

  let (_, p) = r
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

test("should allow mutating observed", t => {
  let p = {name: "John", username: "jo"}
  let r = Core.make(p)
  Core.observe(r, p => {
    open String
    p.name = p.name->toLowerCase->slice(~start=0, ~end=2)
  })

  let (_, p) = r
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

test("should proxy sub-objects", t => {
  let m = {called: false}
  let p = {
    name: "John",
    address: {
      city: "Love",
      zip: 1234,
    },
  }
  let r = Core.make(p)
  let (_, x) = r
  let o = Core._connect(r, () => m.called = true)
  t->is(x.address.city, "Love") // observe 'address.city'
  t->is(m.called, false)

  // Update name before flush
  x.address.city = "Passion"
  // Callback should not be called
  t->is(m.called, false)
  Core._flush(o)

  // Update name with same value after flush
  x.address.city = "Passion"
  // Callback should be called
  t->is(m.called, false)

  // Update name with another value after flush
  x.address.city = "Kindness"
  // Callback should be called
  t->is(m.called, true)
  m.called = false

  // Update again
  x.address.city = "Sorrow"
  // Callback should not be called
  t->is(m.called, false)
})
