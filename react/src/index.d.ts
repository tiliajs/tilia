import type { Tilia } from "tilia";
export interface TiliaReact {
  useTilia: () => void;
  useComputed: <T>(fn: () => T) => signal<A>;
}

export function make(tilia: Tilia): TiliaReact;

export function useTilia(): void;
export function useComputed<T>(fn: () => T): signal<T>;
