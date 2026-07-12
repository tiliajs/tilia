# Tilia

**Tilia** is a simple, powerful state management library for TypeScript and ReScript, designed for data-intensive and highly interactive apps. Built with best practices in mind, Tilia emphasizes *readability* and minimal API surface, making state management nearly invisible in your code.

### Why Tilia for Domain-Driven Design ?

Tilia’s minimal, expressive API lets you model application state and business
logic in the language of your domain—without boilerplate or framework jargon.
Features like `carve` encourage modular, feature-focused state that maps
naturally to DDD’s bounded contexts. Computed properties and derived actions
keep business logic close to your data, making code more readable, maintainable,
and easier to evolve as your domain grows.

In short: Tilia helps you write code that matches your business, not your framework.

For more information, check out the [**DDD section**](https://tiliajs.com/docs#ddd) of the website.

<a href="https://tiliajs.com">
  <img width="834" height="705" alt="image" src="https://github.com/user-attachments/assets/56dd163a-65a0-4900-9280-aab2a0d7d92a" />
</a>

Check the [**website**](https://tiliajs.com) for full documentation and more examples for both TypeScript and ReScript.

For core runtime behavior decisions (including computed pruning), see
[`TRADE_OFFS.md`](./TRADE_OFFS.md).

## Note on exceptions

If a computed or observe callback throws an exception, the exception is caught,
logged to `console.error` and re-thrown at the end of the next flush. This is
done to avoid breaking the application in case of a bug in the callback but
still bubbling the error to the user.

## API (in case the website is not available)

(TypeScript version below)

### ReScript

This is taken directly from Tilia.resi file.

```res
type observer

type signal<'a> = {mutable value: 'a}
type readonly<'a> = {data: 'a}
type setter<'a> = 'a => unit
type deriver<'p> = {
  /** 
   * Return a derived value to be inserted into a tilia object. This is like
   * a computed but with the tilia object as parameter.
   * 
   * @param f The computation function that takes the tilia object as parameter.
   */
  derived: 'a. ('p => 'a) => 'a,
}

type tilia = {
  /** 
   * Transform a regular object or array into a tilia proxy value.
   * 
   * The returned value is reactive: any nested fields or elements are tracked
   * for changes.
   */
  tilia: 'a. 'a => 'a,
  /** 
   * Transform a regular object or array into a tilia proxy value, with the
   * possibility to derive state from the object itself.
   * 
   * The returned value is reactive: any nested fields or elements are tracked
   * for changes.
   */
  carve: 'a. (deriver<'a> => 'a) => 'a,
  /** 
   * Register a callback to be re-run whenever any observed value changes in the
   * default context.
   * 
   * This uses a PUSH model: changes "push" the callback to run.
   *
   * For a PULL model (run only when a value is read), see `computed`.
   *
   * @return A function to stop observing.
   */
  observe: (unit => unit) => unit => unit,
  /** 
   * React to value changes.
  * 
  * The first function captures the values to observe and passes them to the
  * second function. The second function is called whenever any of the observed
  * values changes.
  * 
  * @param f The capture function.
  * @param m The effect function.
  * @return A function to stop watching.
  */
  watch: 'a. (unit => 'a, 'a => unit) => unit => unit,
  /** 
   * Run a series of operations in a batch, blocking notifications until the
   * batch is complete.
   * 
   * Useful for updating multiple reactive values efficiently.
   */
  batch: (unit => unit) => unit,
  /**
   * Wrap a primitive value in a reactive signal. Use this to quickly create a
   * tilia object with a single `value` field and a setter.
   *
   */
  signal: 'a. 'a => (signal<'a>, setter<'a>),
  /**
   * Derive a signal from other signals.
   *
   */
  derived: 'a. (unit => 'a) => signal<'a>,
  /**
   * Return a reactive source value to be inserted into a tilia object.
  *
  * The setup callback is called once on first value read and whenever any 
  * observed value changes. The callback receives a setter function, which 
  * can be used to imperatively update the value. The initial value is used 
  * before the first update.
  *
  * This is useful for implementing resource loaders, state machines or any state
  * that depends on external or asynchronous events.
  * 
  * @param v The initial value.
  * @param f The setup function, receives the previous value and a setter.
  */
  source: 'a 'ignored. ('a, ('a, 'a => unit) => 'ignored) => 'a,
  /**
   * Return a managed value to be inserted into a tilia object.
  *
  * The setup callback runs once when the value is first accessed, and again
  * whenever any observed dependency changes. The callback receives a setter
  * function to imperatively update the value, and should return the initial
  * value.
  *
  * This is useful for implementing event based machines with a simple initial
  * setup.
  * 
  * @param f The setup function, receives a setter and returns the current value.
  */
  store: 'a. (('a => unit) => 'a) => 'a,
  /** 
   * Internal: Register an observer callback.
   */
  _observe: (unit => unit) => observer,
}

/** 
 * Create a new tilia context and return the `tilia`, `observe`, `batch` and
 * `signal` functions.
 *
 * The `gc` parameter controls how many cleared watchers are kept before
 * triggering garbage collection (default: 50).
 * 
 * @param ~gc Maximum cleared watchers before GC (default: 50).
 */
let make: (~gc: int=?) => tilia

/** 
 * Transform a regular object or array into a tilia proxy value.
 * 
 * The returned value is reactive, tracking changes to nested fields or
 * elements.
 * 
 * @param a The object or array to wrap.
 */
let tilia: 'a => 'a

/** 
 * Transform a regular object or array into a tilia proxy value, with the
 * possibility to derive state from the object itself.
 * 
 * The returned value is reactive: any nested fields or elements are tracked for
 * changes.
 */
let carve: (deriver<'a> => 'a) => 'a

/** 
 * Register a callback to be re-run whenever any of the observed values changes.
 * 
 * This uses a PUSH model: changes "push" the callback to run.  For a PULL model
 * (run only when a value is read), see `computed`.
 * 
 * @param f The callback to run on changes.
 * @return A function to stop observing.
 */
let observe: (unit => unit) => unit => unit

/** 
 * React to changes of captured values.
 * 
 * The first function captures values to observe. The second function
 * is called with the returned value from the first function whenever
 * any of the observed values changes.
 * 
 * The effect callback should avoid synchronously mutating captured signals
 * to prevent unexpected recursive updates. Use `observe` for more complex
 * reactive behaviors involving such mutations.
 * 
 * @param f1 The function that captures values to observe.
 * @param f2 The function called when the captured values change.
 * @return A function to stop watching.
 */
let watch: (unit => 'a, 'a => unit) => unit => unit

/** 
 * Run a series of operations in a batch, blocking notifications until the batch
 * is complete.
 * 
 * Useful for updating multiple reactive values efficiently (not needed within a
 * tilia callback such as in `computed` or `observe`)
 * 
 * @param f The function to execute in a batch.
 */
let batch: (unit => unit) => unit

/**
 * Wrap a primitive value in a reactive signal. Use this to quickly create a
 * tilia object with a single `value` field and a setter.
 *
 * @param v The initial value.
 */
let signal: 'a => (signal<'a>, setter<'a>)

/**
 * Derive a signal from other signals.
 *
 */
let derived: (unit => 'a) => signal<'a>

/**
 * Wrap a value in a readonly holder with a non-writable `value` field.
 *
 * Use to insert immutable data into a tilia object and avoid tracking.
 *
 * @param v The initial value.
 */
let readonly: 'a => readonly<'a>

/** 
 * Return a computed value to be inserted into a tilia object.
 *
 * The cached value is computed when the key is read and is destroyed 
 * (invalidated) when any observed value changes.
 *
 * The callback should return the current value.
 * 
 * @param f The computation function.
 */
let computed: (unit => 'a) => 'a

/**
 * Create a computed value that reflects the current value of a signal.
 *
 * This function takes a reactive `signal` and returns a computed value that
 * "lifts" and tracks the inner `value` field of the signal.
 * 
 * @param s The signal to lift as a computed.
 */
let lift: signal<'a> => 'a

/**
 * Return a reactive source value to be inserted into a tilia object.
 *
 * The setup callback is called once on first value read and whenever any 
 * observed value changes. The callback receives a setter function, which 
 * can be used to imperatively update the value. The initial value is used 
 * before the first update.
 *
 * This is useful for implementing resource loaders, state machines or any state
 * that depends on external or asynchronous events.
 * 
 * @param v The initial value.
 * @param f The setup function, receives the previous value and a setter.
 */
let source: ('a, ('a, 'a => unit) => 'ignored) => 'a

/**
 * Return a managed value to be inserted into a tilia object.
 *
 * The setup callback runs once when the value is first accessed, and again
 * whenever any observed dependency changes. The callback receives a setter
 * function to imperatively update the value, and should return the initial
 * value.
 *
 * This is useful for implementing event based machines with a simple initial
 * setup.
 * 
 * @param f The setup function, receives a setter and returns the current value.
 */
let store: (('a => unit) => 'a) => 'a

/** ---------- Internal types and functions for library developers ---------- */
/** 
 * Internal: Register an observer callback.
 */
let _observe: (unit => unit) => observer

/** 
 * Internal: Stop observing.
 */
let _done: observer => unit

/** 
 * Internal: Stop observing and mark an observer as ready to respond. 
 * 
 * If `bool` is true, notify if changed.
 */
let _ready: (observer, bool) => unit

/** 
 * Internal: Dispose of an observer that wasn't notified (notification disposes of observers automatically).
 */
let _clear: observer => unit

/** 
 * Internal: Get meta information on the proxy (raw tree, etc).
 */
let _meta: 'a => nullable<'b>

/** 
 * Internal: Type used by _canopy.
 */
type canopy = {
  live: Set.t<string>,
  idle: Set.t<string>,
}

/**
 * Internal: Inspect which keys have observers (live) versus
 * the ones that are not observed (idle).
 */
let _canopy: 'a => canopy

/** 
 * Internal: The default tilia context.
 */
let _ctx: tilia
```

### TypeScript

```ts
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
```

`_canopy(tree)` is an internal helper for library developers. It flushes
pending notifications, then returns current own keys split into `live` (has
observers) and `idle` (no observers).

## Basic Example

```ts
import { tilia, observe } from "tilia";

const alice = tilia({
  name: "Alice",
  age: 0,
  birthday: dayjs("2015-05-24"),
});

const globals = tilia({ now: dayjs() });

setInterval(() => (globals.now = dayjs()), 1000 * 60);

// The cached computed value is reset if now_.value or alice.birthday changes.
alice.age = computed(() => globals.now.diff(alice.birthday, "year"));

// This will be called every time alice.age changes.
observe(() => {
  console.log("Alice is now", alice.age, "years old !!");
});
```

## Advanced Example

Demonstrates how to use `carve` for features where methods and properties depend on each other.

```ts
export function makeTodos(remote: Remote, data: Todo[]) {
  const todos = carve<Todos>(({ derived }) => ({
    // State
    filter: source(fetchFilter(remote), "all"),
    selected: newTodo(),

    // Computed state
    list: derived(list),
    remaining: derived(remaining),

    // Actions
    clear: derived(clear),
    edit: derived(edit),
    remove: derived(remove),
    save: derived(save),
    setFilter: derived(setFilter),
    setTitle: derived(setTitle),
    toggle: derived(toggle),

    // Private state
    data,
  }));

  return todos;
}
```
