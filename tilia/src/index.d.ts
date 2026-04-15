declare const o: unique symbol;
declare const r: unique symbol;
export type Observer = { readonly [o]: true };
export type Signal<T> = { value: T };
export type Readonly<T> = { readonly data: T };
export type Setter<T> = (v: T) => void;
export type Deriver<U> = { derived: <T>(fn: (p: U) => T) => T };
export type Tilia = {
  /** Transform a regular object or array into a reactive tilia proxy. */
  tilia: <T>(branch: T) => T;
  /** Transform a regular object or array into a reactive tilia proxy, with the possibility to derive state from the object itself. */
  carve: <T>(fn: (deriver: Deriver<T>) => T) => T;
  /** Register a callback to re-run whenever any observed value changes (push reactivity). */
  observe: (fn: () => void) => void;
  /** React to changes: the first function captures values, the second runs when they change. */
  watch: <T>(fn: () => T, effect: (v: T) => void) => void;
  /** Run operations in a batch, blocking notifications until the batch completes. */
  batch: (fn: () => void) => void;
  /** Wrap a primitive in a reactive signal with a `value` field and a setter. */
  signal: <T>(value: T) => Signal<T>;
  /** Derive a signal from other reactive values. */
  derived: <T>(fn: () => T) => Signal<T>;
  /**
   * Return a reactive source value. The setup runs on first read and re-runs
   * when tracked dependencies change. The setter updates the value imperatively.
   */
  source: <T>(initialValue: T, fn: (previous: T, set: Setter<T>) => unknown) => T;
  /**
   * Return a managed value. The setup runs on first access and re-runs when
   * dependencies change. It receives a setter and returns the initial value.
   */
  store: <T>(fn: (set: Setter<T>) => T) => T;
  /** Track key-level writes on a tilia proxy. Returns `{ keys, mute }`. */
  changed: <T>(obj: T, guard?: () => boolean) => Changed;
  /** @internal */
  _observe(callback: () => void): Observer;
};

/**
 * Create a new tilia context with its own `tilia`, `observe`, `batch`, etc.
 * @param gc Maximum cleared watchers before garbage collection (default: 50).
 */
export function make(flush?: (fn: () => void) => void, gc?: number): Tilia;

/** Transform a regular object or array into a reactive tilia proxy. */
export function tilia<T>(branch: T): T;
/** Transform a regular object or array into a reactive tilia proxy, with the possibility to derive state from the object itself. */
export function carve<T>(fn: (deriver: Deriver<T>) => T): T;
/** Register a callback to re-run whenever any observed value changes (push reactivity). */
export function observe(fn: () => void): void;
/**
 * React to changes of captured values. The first function captures values to
 * observe; the second runs with the captured result whenever they change.
 */
export function watch<T>(fn: () => T, effect: (v: T) => void): void;
/** Run operations in a batch, blocking notifications until the batch completes. */
export function batch(fn: () => void): void;

/** Return a computed value. Cached on read, invalidated when observed values change (pull reactivity). */
export function computed<T>(fn: () => T): T;
/**
 * Return a reactive source value. The setup runs on first read and re-runs
 * when tracked dependencies change. The setter updates the value imperatively.
 */
export function source<T>(
  initialValue: T,
  fn: (previous: T, set: Setter<T>) => unknown
): T;
/**
 * Return a managed value. The setup runs on first access and re-runs when
 * dependencies change. It receives a setter and returns the initial value.
 */
export function store<T>(fn: (set: Setter<T>) => T): T;
/** Wrap a value in a readonly holder to avoid tracking. */
export function readonly<T>(data: T): Readonly<T>;
/** Wrap a primitive in a reactive signal with a `value` field and a setter. */
export function signal<T>(value: T): [Signal<T>, Setter<T>];
/** Derive a signal from other reactive values. */
export function derived<T>(fn: () => T): Signal<T>;
/** Lift a signal into a computed value that tracks its inner `value` field. */
export function lift<T>(s: Signal<T>): T;
export interface Changed {
  /** Capture function for `watch`. Drains accumulated keys on read. */
  keys: () => string[];
  /** Run a callback with tracking temporarily removed. Includes `batch`. */
  mute: (fn: () => void) => void;
}

/**
 * Track key-level writes on a tilia proxy. Returns `{ keys, mute }`.
 * `keys` is a capture function for `watch` that drains accumulated keys.
 * `mute` runs code without tracking (for inbound sync writes).
 * Each call creates an independent accumulator. When `guard` returns false,
 * keys accumulate silently; when it becomes true, all accumulated keys drain.
 */
export function changed<T>(obj: T, guard?: () => boolean): Changed;

/** @internal */
export function _observe(callback: () => void): Observer;
/** @internal */
export function _done(observer: Observer): void;
/** @internal */
export function _ready(observer: Observer, notifyIfChanged?: boolean): void;
/** @internal */
export function _clear(observer: Observer): void;
/** @internal */
export function _meta<T>(tree: T): unknown;
/** @internal */
export const _ctx: Tilia;
