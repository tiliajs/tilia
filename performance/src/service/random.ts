import { signal, type Signal } from "tilia";
import type { Random } from "@service/random";

export const random: Random = {
  random: (seed) => mulberry32((seed * 2 ** 32) >>> 0),
};

// From https://stackoverflow.com/questions/521295/seeding-the-random-number-generator-in-javascript
function mulberry32(a: number): [Signal<number>, () => number] {
  const [count, setCount] = signal(0);
  return [
    count,
    function () {
      setCount(count.value + 1);
      let t = (a += 0x6d2b79f5);
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    },
  ];
}
