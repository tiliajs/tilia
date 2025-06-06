declare const o: unique symbol;
declare const r: unique symbol;
export type Observer = { readonly [o]: true };
export type Tilia = {
  tilia: <a>(branch: a) => a;
  computed: <a>(fn: () => a) => a;
  observe: (fn: () => void) => void;
  _clear(observer: Observer): void;
  _observe<a>(tree: a, callback: () => void): Observer;
  _ready(observer: Observer, notifyIfChanged?: boolean): void;
  _meta<a>(tree: a): unknown;
};
export function make(flush?: (fn: () => void) => void): Tilia;

// Default global context

export function tilia<a>(branch: a): a;
export function computed<a>(fn: () => a): a;
export function observe(fn: () => void): void;

export function _clear(observer: Observer): void;
export function _observe<a>(tree: a, callback: () => void): Observer;
export function _ready(observer: Observer, notifyIfChanged?: boolean): void;
export function _meta<a>(tree: a): unknown;
