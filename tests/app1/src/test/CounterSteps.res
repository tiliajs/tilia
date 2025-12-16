open VitestBdd

given("counter is initialized", ({step}, _) => {
  let counter = Counter.make()

  step("I increment the counter", () => {
    counter.increment()
  })

  step("I decrement the counter", () => {
    counter.decrement()
  })

  step("I set counter to {number}", (value: float) => {
    counter.value = value
  })

  step("counter value should be {number}", (expected: float) => {
    expect(counter.value).toBe(expected)
  })

  step("counter double should be {number}", (expected: float) => {
    expect(counter.double).toBe(expected)
  })

  step("counter should notify observers on change", () => {
    let values: array<float> = []
    Counter.observeCounter(
      counter,
      value => {
        values->Array.push(value)
      },
    )

    counter.value = 10.0
    counter.value = 20.0

    expect(values).toEqual([0.0, 10.0, 20.0])
  })
})
