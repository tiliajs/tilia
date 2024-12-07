open Ava
open Assert
type person = {mutable name: string, mutable username: string}
type tester = {mutable called: bool}

test("should track leaf changes", t => {
  let m = {called: false}
  let p = {name: "John", username: "jo"}
  let r = Tilia.init(p)
  let (_, x) = r
  let o = Tilia.connect(r, () => m.called = true)
  t->is(x.name, "John") // observe 'name'
  t->is(m.called, false)

  // Update name before flush
  x.name = "One"
  // Callback should not be called
  t->is(m.called, false)
  Tilia.flush(o)

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
