import type { Signal } from "tilia";

export interface Random {
  // Create a random generator from a seed in [0, 1[. The random numbers are [0, 1[
  random: (seed: number) => [Signal<number>, () => number];
}
