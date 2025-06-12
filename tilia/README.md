# Tilia

This is the core library for tilia state management. For documentation, please
see the [monorepo](https://github.com/tiliajs/tilia/blob/main/README.md).

Check the [**website**](https://tiliajs.com) for documentation and examples for TypeScript and ReScript.

## API (in case the website is not available)

(TypeScript version below)

### ReScript

This is taken directly from Tilia.resi file.

```res
type observer
type meta<'a>

type signal<'a> = {value: 'a}
type setter<'a> = 'a => unit
type tilia = {
  /** Transform a reguarl object or array into a tilia value.
   */
  tilia: 'a. 'a => 'a,
  /** Return a computed value to be inserted into a tilia proxy. The cached value
   * is computed when the key is read and destroyed when any observed value is
   * changed.
   *
   * The first parameter to the callback is the "connected" object.
   */
  computed: 'b. (unit => 'b) => 'b,
  /** Re-runs a callback whenever any of the observed values changes.
   * The observer implements a PUSH model (changes "push" the callback to run).
   *
   * See "computed" for a PULL model where the callback is only called when the
   * produced value is read.
   */
  observe: (unit => unit) => unit,
  /** extras */
  /** Create a mutable value and a setter function */
  signal: 'a. 'a => (signal<'a>, 'a => unit),
  /** Create a store (a signal with a setter) */
  store: 'a. (('a => unit) => 'a) => signal<'a>,
  /** Internal */
  _observe: (unit => unit) => observer,
  /** Internal */
  _done: observer => unit,
  /** Internal */
  _ready: (observer, bool) => unit,
  /** Internal */
  _clear: observer => unit,
  /** Internal */
  _meta: 'a. 'a => nullable<meta<'a>>,
}

/** Create a new tilia context and returns the `tilia` and `observe` functions.
 * The default flush function is set to notify immediately (as soon as we are not in an observing function).
 * The gc parameter is the number of cleared watchers to keep before triggering a GC (default is 50).
 */
let make: (~flush: (unit => unit) => unit=?, ~gc: int=?) => tilia

/** Transform a reguarl object or array into a tilia value.
 */
let tilia: 'a => 'a

/** Return a computed value to be inserted into a tilia proxy. The cached value
 * is computed when the key is read and destroyed when any observed value is
  * changed.
  *
  * The first parameter to the callback is the "connected" object.
  */
let computed: (unit => 'a) => 'a

/** Re-runs a callback whenever any of the observed values changes in the default context.
 * The observer implements a PUSH model (changes "push" the callback to run).
  *
  * See "computed" for a PULL model where the callback is only called when the
  * produced value is read.
  */
let observe: (unit => unit) => unit

/** extras */
/** Create a mutable value and a setter function */
let signal: 'a => (signal<'a>, 'a => unit)
/** Create a store (a signal with a setter) */
let store: (('a => unit) => 'a) => signal<'a>

/** Internal types for library developers (global context) */
/** Start observing */
let _observe: (unit => unit) => observer
/** Stop observing */
let _done: observer => unit
/** Ready to respond, bool = notify if changed */
let _ready: (observer, bool) => unit
/** Dispose of an observer */
let _clear: observer => unit
/** Get meta information (mostly for stats) */
let _meta: 'a => nullable<meta<'a>>
/** Default context */
let _ctx: tilia
```

### TypeScript

```ts
declare const o: unique symbol;
declare const r: unique symbol;
export type Observer = { readonly [o]: true };
export type Signal<T> = { readonly value: T };
export type Setter<T> = (v: T) => void;
export type Tilia = {
  tilia: <T>(branch: T) => T;
  computed: <T>(fn: () => T) => T;
  observe: (fn: () => void) => void;

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

// extra
export function signal<T>(value: T): [Signal<T>, Setter<T>];
export function store<T>(init: (setter: Setter<T>) => T): Signal<T>;

// internal
export function _clear(observer: Observer): void;
export function _observe(callback: () => void): Observer;
export function _done(observer: Observer): void;
export function _ready(observer: Observer, notifyIfChanged?: boolean): void;
export function _meta<T>(tree: T): unknown;
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
