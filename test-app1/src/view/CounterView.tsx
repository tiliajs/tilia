import { useTilia } from "@tilia/react";
import { type counter as Counter } from "../domain/Counter.gen";

type CounterProps = {
  counter: Counter;
};

export function CounterView({ counter }: CounterProps) {
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
