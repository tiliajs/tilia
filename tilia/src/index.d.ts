declare const o: unique symbol;
declare const r: unique symbol;
export type Observer = { readonly [o]: true };
export type Signal<a> = { readonly value: a };
export type Setter<a> = (v: a) => void;
export type Tilia = {
  tilia: <a>(branch: a) => a;
  computed: <a>(fn: () => a) => a;
  observe: (fn: () => void) => void;

  // extra
  signal: <a>(value: a) => [Signal<a>, Setter<a>];
  store: <a>(init: (setter: Setter<a>) => a) => Signal<a>;

  // internal
  _clear(observer: Observer): void;
  _observe(callback: () => void): Observer;
  _ready(observer: Observer, notifyIfChanged?: boolean): void;
  _meta<a>(tree: a): unknown;
};
export function make(flush?: (fn: () => void) => void, gc?: number): Tilia;

// Default global context

export function tilia<a>(branch: a): a;
export function computed<a>(fn: () => a): a;
export function observe(fn: () => void): void;

// extra
export function signal<a>(value: a): [Signal<a>, Setter<a>];
export function store<a>(init: (setter: Setter<a>) => a): Signal<a>;

// internal
export function _clear(observer: Observer): void;
export function _observe(callback: () => void): Observer;
export function _ready(observer: Observer, notifyIfChanged?: boolean): void;
export function _meta<a>(tree: a): unknown;
