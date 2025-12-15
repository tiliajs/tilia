import { useTilia } from "@tilia/react";
import { type Counter } from "../domain/counter";

type CounterProps = {
  counter: Counter;
};

export function Counter({ counter }: CounterProps) {
  useTilia();

  return (
    <div>
      <div role="status" aria-label="Value">Value: {counter.value}</div>
      <div role="status" aria-label="Double">Double: {counter.double}</div>
      <button onClick={() => counter.increment()}>Increment</button>
      <button onClick={() => counter.decrement()}>Decrement</button>
    </div>
  );
}
