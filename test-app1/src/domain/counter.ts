import { tilia, computed, observe } from "tilia";

export type Counter = {
  value: number;
  double: number;
  increment: () => void;
  decrement: () => void;
};

export const make = (): Counter => {
  const counter = tilia({
    value: 0,
    double: computed(() => counter.value * 2),
    increment: () => {
      counter.value++;
    },
    decrement: () => {
      counter.value--;
    },
  });
  return counter;
};

export function observeCounter(counter: Counter, callback: (value: number) => void) {
  return observe(() => {
    callback(counter.value);
  });
}
