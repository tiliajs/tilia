declare const o: unique symbol;
declare const r: unique symbol;
export type Observer = { readonly [o]: true };
export type Signal<T> = { readonly value: T };
export type Setter<T> = (v: T) => void;
export type Tilia = {
  tilia: <T>(branch: T) => T;
  computed: <T>(fn: () => T) => T;
  observe: (fn: () => void) => void;
  batch: (fn: () => void) => void;

  // extra
  signal: <T>(value: T) => [Signal<T>, Setter<T>];
  store: <T>(init: (setter: Setter<T>) => T) => Signal<T>;

  // internal
  _clear(observer: Observer): void;
  _done(observer: Observer): void;
  _observe(callback: () => void): Observer;
  _ready(observer: Observer, notifyIfChanged?: boolean): void;
  _meta<T>(tree: T): unknown;
};
export function make(flush?: (fn: () => void) => void, gc?: number): Tilia;

// Default global context

export function tilia<T>(branch: T): T;
export function computed<T>(fn: () => T): T;
export function observe(fn: () => void): void;
export function batch(fn: () => void): void;

// extra
export function signal<T>(value: T): [Signal<T>, Setter<T>];
export function store<T>(init: (setter: Setter<T>) => T): Signal<T>;

// internal
export function _clear(observer: Observer): void;
export function _observe(callback: () => void): Observer;
export function _done(observer: Observer): void;
export function _ready(observer: Observer, notifyIfChanged?: boolean): void;
export function _meta<T>(tree: T): unknown;
