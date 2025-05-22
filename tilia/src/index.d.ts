declare const o: unique symbol;
declare const r: unique symbol;
export type Observer = { readonly [o]: true };
export type Tilia = {
  connect: <a>(branch: a) => a;
  observe: (fn: () => void) => void;
  // We could expose the first argument of the computed function if needed but in
  // TS, we can have p referenced in computed through the closure so we don't need
  // it.
  computed: <a>(fn: () => a) => a;
  update: <a>(v: a, fn: () => a) => void;
  move: <a>(v: a, fn: (setter: (v: a) => void) => void) => void;
};
export function make(flush?: (fn: () => void) => void): Tilia;
export function _clear(observer: Observer): void;
export function _observe<a>(tree: a, callback: () => void): Observer;
export function _ready(observer: Observer, notifyIfChanged?: boolean): void;
export function _meta<a>(tree: a): unknown;
