import type { Tilia } from "tilia";
export interface TiliaReact {
  useTilia: () => void;
  useComputed: <T>(fn: () => T) => signal<A>;
  leaf: <T, U>(fn: (p: T) => U) => (p: T) => U;
}

export function make(tilia: Tilia): TiliaReact;

export function useTilia(): void;
export function useComputed<T>(fn: () => T): T;
export function leaf<T, U>(fn: (p: T) => U): (p: T) => U;
