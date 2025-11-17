declare const o: unique symbol;
declare const r: unique symbol;
export type Observer = { readonly [o]: true };
export type Signal<T> = { value: T };
export type Readonly<T> = { readonly data: T };
export type Setter<T> = (v: T) => void;
export type Deriver<U> = { derived: <T>(fn: (p: U) => T) => T };
export type Tilia = {
  tilia: <T>(branch: T) => T;
  carve: <T>(fn: (deriver: Deriver<T>) => T) => T;
  observe: (fn: () => void) => void;
  watch: <T>(fn: () => T, effect: (v: T) => void) => void;
  batch: (fn: () => void) => void;
  signal: <T>(value: T) => Signal<T>;
  derived: <T>(fn: () => T) => Signal<T>;
  source: <T>(initialValue: T, fn: (previous: T, set: Setter<T>) => unknown) => T;

  // Internal
  _observe(callback: () => void): Observer;
};
export function make(flush?: (fn: () => void) => void, gc?: number): Tilia;

// Default global context
export function tilia<T>(branch: T): T;
export function carve<T>(fn: (deriver: Deriver<T>) => T): T;
export function observe(fn: () => void): void;
export function watch<T>(fn: () => T, effect: (v: T) => void): void;
export function batch(fn: () => void): void;

// Functional reactive programming
export function computed<T>(fn: () => T): T;
export function source<T>(
  initialValue: T,
  fn: (previous: T, set: Setter<T>) => unknown
): T;
export function store<T>(fn: (set: Setter<T>) => T): T;
export function readonly<T>(data: T): Readonly<T>;
export function signal<T>(value: T): [Signal<T>, Setter<T>];
export function derived<T>(fn: () => T): Signal<T>;
export function lift<T>(s: Signal<T>): T;

// Internal
export function _observe(callback: () => void): Observer;
export function _done(observer: Observer): void;
export function _ready(observer: Observer, notifyIfChanged?: boolean): void;
export function _clear(observer: Observer): void;
export function _meta<T>(tree: T): unknown;
export const _ctx: Tilia;
