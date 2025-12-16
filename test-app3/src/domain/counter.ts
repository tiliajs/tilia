import { carve } from "tilia";

export type Counter = {
  value: number;
  readonly double: number;
  readonly increment: () => void;
  readonly decrement: () => void;
};

const increment = (self: Counter) => () => {
  self.value += 1;
};

const decrement = (self: Counter) => () => {
  self.value -= 1;
};

const double = (self: Counter) => self.value * 2;

export const make = () => {
  return carve<Counter>(({ derived }) => ({
    value: 0,
    double: derived(double),
    increment: derived(increment),
    decrement: derived(decrement),
  }));
};
