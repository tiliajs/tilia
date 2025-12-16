import { leaf, useTilia } from "@tilia/react";
import { Counter as CounterType } from "../domain/counter";

type CounterProps = {
  counter: CounterType;
};

export const Counter = ({ counter }: CounterProps) => {
  useTilia();

  return (
    <div>
      <div role="status" aria-label="Value">Value: {counter.value}</div>
      <div role="status" aria-label="Double">Double: {counter.double}</div>
      <button onClick={() => counter.increment()}>Increment</button>
      <button onClick={() => counter.decrement()}>Decrement</button>
    </div>
  );
};

export const CounterLeaf = leaf(({ counter }: CounterProps) =>
  <div>
    <div role="status" aria-label="Value">Value: {counter.value}</div>
    <div role="status" aria-label="Double">Double: {counter.double}</div>
    <button onClick={() => counter.increment()}>Increment</button>
    <button onClick={() => counter.decrement()}>Decrement</button>
  </div>
);