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

type tilia = {
  /** Create a new tilia proxy and connect it to the forest.
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

  /** Internal */
  _observe: (unit => unit) => observer,
  /** Internal */
  _ready: (observer, bool) => unit,
  /** Internal */
  _clear: observer => unit,
  /** Internal */
  _meta: 'a. 'a => nullable<meta<'a>>,
}

/** Create a new tilia context and returns the `connect` and `observe` functions.
 * The default flush function is set to notify immediately (as soon as we are not in an observing function).
 */
let make: (~flush: (unit => unit) => unit=?) => tilia

/** Create a new tilia proxy and connect it to the default context (forest).
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

/** Internal types for library developers (global context) */
/** internal */
let _observe: (unit => unit) => observer
/** internal */
let _ready: (observer, bool) => unit
/** Dispose of an observer */
let _clear: observer => unit
/** Get meta information (mostly for stats) */
let _meta: 'a => nullable<meta<'a>>
```

### TypeScript

```ts
type Observer = {};
type Meta<T> = {
  /* internal implementation details */
};

export interface Tilia {
  /**
   * Create a new tilia proxy and connect it to the forest.
   */
  tilia: <T>(value: T) => T;

  /**
   * Return a computed value to be inserted into a tilia proxy.
   * The cached value is computed when read and invalidated when dependencies change.
   */
  computed: <T>(fn: () => T) => T;

  /**
   * Re-run callback whenever observed values change (PUSH model).
   * Changes automatically trigger the callback.
   */
  observe: (fn: () => void) => void;

  // Internal methods
  /** @internal */
  _observe: (fn: () => void) => Observer;
  /** @internal */
  _ready: (observer: Observer, immediate: boolean) => void;
  /** @internal */
  _clear: (observer: Observer) => void;
  /** @internal */
  _meta: <T>(value: T) => Meta<T> | null;
}

/**
 * Create a new Tilia context with optional custom flush timing
 */
export function make(options?: {
  flush?: (callback: () => void) => void;
}): Tilia;

// Global context functions
export const tilia: Tilia["tilia"];
export const computed: Tilia["computed"];
export const observe: Tilia["observe"];

// Internal global methods
/** @internal */
export const _observe: Tilia["_observe"];
/** @internal */
export const _ready: Tilia["_ready"];
/** @internal */
export const _clear: Tilia["_clear"];
/** @internal */
export const _meta: Tilia["_meta"];
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
