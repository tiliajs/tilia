import { make, observeCounter, type Counter } from "./counter";
import { expect } from "vitest";
import { Given } from "vitest-bdd";

Given("counter is initialized", function ({ When, Then }) {
  // Create a new counter instance for each scenario (enables parallelism)
  const counter = make();

  // ReScript integration: Test that ReScript can use TypeScript counter
  // This is tested via the counter.feature scenarios

  When("I increment the counter", () => {
    counter.increment();
  });

  When("I decrement the counter", () => {
    counter.decrement();
  });

  When("I set counter to {number}", (value: number) => {
    counter.value = value;
  });

  Then("counter value should be {number}", (expected: number) => {
    expect(counter.value).toBe(expected);
  });

  Then("counter double should be {number}", (expected: number) => {
    expect(counter.double).toBe(expected);
  });

  Then("counter should notify observers on change", () => {
    const values: number[] = [];
    observeCounter(counter, (value) => {
      values.push(value);
    });

    counter.value = 10;
    counter.value = 20;

    expect(values).toEqual([0, 10, 20]);
  });
});
