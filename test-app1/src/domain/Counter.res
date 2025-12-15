// Import TypeScript counter using raw JS access
@module("./counter.ts") @val external counter: 'a = "counter"

let testCounter = () => {
  // Test that we can use TypeScript counter in ReScript
  let _ = %raw("counter.value = 0")
  let _ = %raw("counter.increment()")
  let _ = %raw("counter.increment()")
  %raw("counter.value") == 2
}

let testDouble = () => {
  let _ = %raw("counter.value = 5")
  %raw("counter.double") == 10
}

let testDecrement = () => {
  let _ = %raw("counter.value = 10")
  let _ = %raw("counter.decrement()")
  %raw("counter.value") == 9
}
