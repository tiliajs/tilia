# Tilia

**Tilia** is a simple, powerful state management library for TypeScript and ReScript, designed for data-intensive and highly interactive apps. Built with best practices in mind, Tilia emphasizes _readability_ and minimal API surface, making state management nearly invisible in your code.

### Why Tilia for Domain-Driven Design ?

Tilia’s minimal, expressive API lets you model application state and business logic in the language of your domain—without boilerplate or framework jargon. Features like `carve` encourage modular, feature-focused state that maps naturally to DDD’s bounded contexts. Computed properties and derived actions keep business logic close to your data, making code more readable, maintainable, and easier to evolve as your domain grows.

In short: Tilia helps you write code that matches your business, not your framework.

For more information, check out the [**DDD section**](https://tiliajs.com/docs#ddd) of the website.

<a href="https://tiliajs.com">
  <img width="834" height="705" alt="image" src="https://github.com/user-attachments/assets/56dd163a-65a0-4900-9280-aab2a0d7d92a" />
</a>

Check the [**website**](https://tiliajs.com) for full documentation and more examples for both TypeScript and ReScript.

## API for versin **2.x** (in case the website is not available)

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
   */
  observe: (unit => unit) => unit,
  /**
   * React to value changes.
  *
  * The first function captures the values to observe and passes them to the
  * second function. The second function is called whenever any of the observed
  * values changes.
  *
  * @param f The capture function.
  * @param m The effect function.
  */
  watch: 'a. (unit => 'a, 'a => unit) => unit,
  /**
   * Run a series of operations in a batch, blocking notifications until the
   * batch is complete.
   *
   * Useful for updating multiple reactive values efficiently.
   */
  batch: (unit => unit) => unit,
  /**
   * Wrap a primitive value in a reactive signal. Use this to quickly create a
   * tilia object with a single `value` field.
   *
   */
  signal: 'a. 'a => signal<'a>,
  /**
   * Derive a signal from other signals.
   *
   */
  derived: 'a. (unit => 'a) => signal<'a>,
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
 */
let observe: (unit => unit) => unit

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
 */
let watch: (unit => 'a, 'a => unit) => unit

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
 * tilia object with a single `value` field.
 *
 * @param v The initial value.
 */
let signal: 'a => signal<'a>

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
 * @param f The setup function, receives a setter.
 * @param v The initial value.
 */
let source: (('a => unit) => 'ignored, 'a) => 'a

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
 * Internal: The default tilia context.
 */
let _ctx: tilia
```

### TypeScript

```ts
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
  batch: (fn: () => void) => void;
  signal: <T>(value: T) => Signal<T>;
  derived: <T>(fn: () => T) => Signal<T>;

  // Internal
  _observe(callback: () => void): Observer;
};
export function make(flush?: (fn: () => void) => void, gc?: number): Tilia;

// Default global context
export function tilia<T>(branch: T): T;
export function carve<T>(fn: (deriver: Deriver<T>) => T): T;
export function observe(fn: () => void): void;
export function batch(fn: () => void): void;

// Functional reactive programming
export function computed<T>(fn: () => T): T;
export function source<T, Ignored>(
  fn: (set: Setter<T>) => Ignored,
  initialValue: T
): T;
export function store<T>(fn: (set: Setter<T>) => T): T;
export function readonly<T>(data: T): Readonly<T>;
export function signal<T>(value: T): Signal<T>;
export function derived<T>(fn: () => T): Signal<T>;

// Internal
export function _observe(callback: () => void): Observer;
export function _done(observer: Observer): void;
export function _ready(observer: Observer, notifyIfChanged?: boolean): void;
export function _clear(observer: Observer): void;
export function _meta<T>(tree: T): unknown;
export const _ctx: Tilia;
```

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

See the [full source code](https://github.com/tiliajs/tilia/blob/main/todo-app-ts/src/domain/feature/todos/todos.ts).

```ts
export function makeTodos(repo: RepoReady, data: Todo[]) {
  return carve<Todos>(({ derived }) => ({
    // State
    filter: source(fetchFilter(repo), "all"),
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
    repo,
    data,
  }));
}
```
