import type { Tilia } from "tilia";
export interface TiliaReact {
  /** Call at the top of a React component to enable reactive tracking. Prefer `leaf` instead. */
  useTilia: () => void;
  /** Compute a value and only re-render when the result changes, not the dependencies. */
  useComputed: <T>(fn: () => T) => T;
  /** Wrap a React component for exact dependency tracking (preferred over `useTilia`). */
  leaf: <T, U>(fn: (p: T) => U) => (p: T) => U;
}

/** Create a `@tilia/react` API from a tilia context. */
export function make(tilia: Tilia): TiliaReact;

/** Call at the top of a React component to enable reactive tracking. Prefer `leaf` instead. */
export function useTilia(): void;
/** Compute a value and only re-render when the result changes, not the dependencies. */
export function useComputed<T>(fn: () => T): T;
/** Wrap a React component for exact dependency tracking (preferred over `useTilia`). */
export function leaf<T, U>(fn: (p: T) => U): (p: T) => U;
