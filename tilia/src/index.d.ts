declare const o: unique symbol;
export type Observer = { readonly [o]: true };
/** A reactive holder for a single value, read and written through `value`. */
export type Signal<T> = { value: T };
/** An immutable holder: the `data` field is not tracked nor proxied. */
export type Readonly<T> = { readonly data: T };
/** Imperative update function returned alongside signals and passed to setups. */
export type Setter<T> = (v: T) => void;
/** Stop function returned by `observe` and `watch`. Calling it cancels the subscription. */
export type Cancel = () => void;
/** Helper passed to `carve` to declare values derived from the object under construction. */
export type Deriver<U> = {
  /**
   * Declare a derived (computed) field inside a `carve` definition. Works like
   * `computed`, but the computation receives the carved object itself, so a
   * field can depend on sibling fields.
   *
   * ```ts
   * const alice = carve(({ derived }) => ({
   *   birthYear: 1995,
   *   age: derived((self) => thisYear - self.birthYear),
   * }));
   * ```
   */
  derived: <T>(fn: (p: U) => T) => T;
};

/** A tilia context: an isolated reactive scope with its own tracking and scheduling. */
export type Tilia = {
  /**
   * Transform a regular object or array into a reactive tilia proxy.
   *
   * Reads are tracked per key, including nested objects and arrays, so
   * observers only re-run when a key they actually read changes. Calling
   * `tilia` twice on the same object returns the same proxy.
   */
  tilia: <T>(branch: T) => T;
  /**
   * Build a reactive object whose derived fields can read the object itself.
   * The callback receives a {@link Deriver} and must return the object to
   * proxy. Use this to co-locate state and computations in one definition.
   */
  carve: <T>(fn: (deriver: Deriver<T>) => T) => T;
  /**
   * Run `fn` now and re-run it whenever any tilia value it read changes
   * (push reactivity).
   *
   * @returns A function that stops the observation.
   */
  observe: (fn: () => void) => Cancel;
  /**
   * React to changes with a clear separation between reading and acting:
   * `fn` captures (reads) values and returns a result; `effect` runs with
   * that result whenever a captured value changes. Unlike `observe`, the
   * effect itself is not tracked, so it can freely read other reactive state.
   *
   * @returns A function that stops watching.
   */
  watch: <T>(fn: () => T, effect: (v: T) => void) => Cancel;
  /**
   * Run several mutations as one batch: notifications are deferred until the
   * batch completes, so observers see a single consistent update. Not needed
   * inside tilia callbacks (`observe`, `computed`, ...) where batching is
   * already active.
   */
  batch: (fn: () => void) => void;
  /**
   * Wrap a single value in a reactive {@link Signal}. Returns the signal and
   * a setter: read with `s.value`, write with the setter.
   */
  signal: <T>(value: T) => [Signal<T>, Setter<T>];
  /**
   * Create a signal whose value is computed from other reactive values and
   * recomputed when they change.
   */
  derived: <T>(fn: () => T) => Signal<T>;
  /**
   * Create a reactive source value to insert into a tilia object. The setup
   * runs on first read and re-runs when any tilia value it read changes. It
   * receives the previous value and a setter for imperative (possibly async)
   * updates; `initialValue` is used until the first `set`.
   *
   * Useful for resource loaders, state machines, or any state driven by
   * external or asynchronous events.
   */
  source: <T>(initialValue: T, fn: (previous: T, set: Setter<T>) => unknown) => T;
  /**
   * Create a managed value to insert into a tilia object. The setup runs on
   * first read and re-runs when any tilia value it read changes. It receives
   * a setter for later imperative updates and must return the initial value.
   *
   * Like `source`, but the initial value is produced by the setup itself.
   */
  store: <T>(fn: (set: Setter<T>) => T) => T;
  /** @internal Register a raw observer (library authors; see `_observe`). */
  _observe(callback: () => void): Observer;
};

/**
 * Create a new tilia context with its own `tilia`, `observe`, `batch`, etc.
 * State from different contexts is tracked and flushed independently.
 *
 * @param gc Number of cleared watchers to keep before triggering garbage
 *           collection (default: 50).
 */
export function make(gc?: number): Tilia;

/**
 * Transform a regular object or array into a reactive tilia proxy (in the
 * default context).
 *
 * Reads are tracked per key, including nested objects and arrays, so
 * observers only re-run when a key they actually read changes. Calling
 * `tilia` twice on the same object returns the same proxy.
 */
export function tilia<T>(branch: T): T;
/**
 * Build a reactive object whose derived fields can read the object itself.
 * The callback receives a {@link Deriver} and must return the object to
 * proxy. Use this to co-locate state and computations in one definition.
 */
export function carve<T>(fn: (deriver: Deriver<T>) => T): T;
/**
 * Run `fn` now and re-run it whenever any tilia value it read changes
 * (push reactivity). For pull reactivity (recompute only when read), see
 * `computed`.
 *
 * @returns A function that stops the observation.
 */
export function observe(fn: () => void): Cancel;
/**
 * React to changes with a clear separation between reading and acting:
 * `fn` captures (reads) values and returns a result; `effect` runs with that
 * result whenever a captured value changes. Unlike `observe`, the effect
 * itself is not tracked, so it can freely read other reactive state.
 *
 * The effect should avoid synchronously mutating the values it captures, to
 * prevent recursive updates; use `observe` for such feedback loops.
 *
 * @returns A function that stops watching.
 */
export function watch<T>(fn: () => T, effect: (v: T) => void): Cancel;
/**
 * Run several mutations as one batch: notifications are deferred until the
 * batch completes, so observers see a single consistent update. Not needed
 * inside tilia callbacks (`observe`, `computed`, ...) where batching is
 * already active.
 */
export function batch(fn: () => void): void;

/**
 * Create a computed value to insert into a tilia object (pull reactivity).
 * The value is computed on first read, cached, and invalidated when any tilia
 * value it read changes; it is only recomputed on the next read.
 */
export function computed<T>(fn: () => T): T;
/**
 * Create a reactive source value to insert into a tilia object. The setup
 * runs on first read and re-runs when any tilia value it read changes. It
 * receives the previous value and a setter for imperative (possibly async)
 * updates; `initialValue` is used until the first `set`.
 *
 * Useful for resource loaders, state machines, or any state driven by
 * external or asynchronous events.
 */
export function source<T>(
  initialValue: T,
  fn: (previous: T, set: Setter<T>) => unknown
): T;
/**
 * Create a managed value to insert into a tilia object. The setup runs on
 * first read and re-runs when any tilia value it read changes. It receives a
 * setter for later imperative updates and must return the initial value.
 *
 * Like `source`, but the initial value is produced by the setup itself.
 */
export function store<T>(fn: (set: Setter<T>) => T): T;
/**
 * Wrap a value in a {@link Readonly} holder. The wrapped data is not proxied
 * nor tracked: use this to insert immutable or foreign objects (class
 * instances, large blobs) into a tilia object without reactivity overhead.
 */
export function readonly<T>(data: T): Readonly<T>;
/**
 * Wrap a single value in a reactive {@link Signal}. Returns the signal and a
 * setter: read with `s.value`, write with the setter.
 */
export function signal<T>(value: T): [Signal<T>, Setter<T>];
/**
 * Create a signal whose value is computed from other reactive values and
 * recomputed when they change.
 */
export function derived<T>(fn: () => T): Signal<T>;
/**
 * Lift a signal into a computed value to insert into a tilia object: the
 * field tracks the signal's inner `value`.
 *
 * ```ts
 * const app = tilia({ user: lift(userSignal) });
 * app.user; // stays in sync with userSignal.value
 * ```
 */
export function lift<T>(s: Signal<T>): T;

/** @internal Keys with observers (`live`) versus keys without (`idle`). */
export type Canopy = { live: Set<string>; idle: Set<string> };
/** @internal Inspect which keys of a tilia proxy are observed. */
export function _canopy<T extends object>(tree: T): Canopy;
/**
 * @internal Register `callback` as an observer and start recording reads.
 * Entry point for library authors building on tilia; pair with `_done` /
 * `_ready` / `_clear`.
 */
export function _observe(callback: () => void): Observer;
/** @internal Stop recording reads for `observer` without subscribing it. */
export function _done(observer: Observer): void;
/**
 * @internal Stop recording and subscribe the observer to the recorded reads.
 * If `notifyIfChanged` is true, notify immediately when a read value already
 * changed during recording.
 */
export function _ready(observer: Observer, notifyIfChanged?: boolean): void;
/** @internal Dispose of an observer that was not notified (notification disposes automatically). */
export function _clear(observer: Observer): void;
/** @internal Get meta information on a tilia proxy (raw target, root, etc.). */
export function _meta<T>(tree: T): unknown;
/** @internal The default tilia context (used by the top-level exports). */
export const _ctx: Tilia;
