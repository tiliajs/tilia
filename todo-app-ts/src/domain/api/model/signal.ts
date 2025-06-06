import { tilia } from "tilia";

export type Signal<T> = { value: T };

export function signal<T>(value: T): [Signal<T>, (v: T) => void] {
  const s = tilia({ value });
  const set = (v: T) => (s.value = v);
  return [s, set] as const;
}
