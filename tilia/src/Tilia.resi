type observer
type meta<'a>

type s<'a> = {mutable value: 'a}
type t = {
  /** Create a new tilia proxy and connect it to the forest.
   */
  connect: 'a. 'a => 'a,
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
  /** Syntax sugar to create a signal and a setter */
  signal: 'a. 'a => (s<'a>, 'a => unit),
  /** Syntax sugar to create a derived signal */
  derived: 'a. (unit => 'a) => s<'a>,
  /** Syntax sugar to create a state machine: the update function receives
   * the current value and a setter.
   */
  update: 'a. ('a, ('a, 'a => unit) => unit) => s<'a>,
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
 * The default flush function is set to notify on the next event loop (setTimeout).
 */
let make: (~flush: (unit => unit) => unit=?) => t

/** Create a new tilia proxy and connect it to the default context (forest).
 */
let connect: 'a => 'a

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

/** Syntax sugar to create a signal and a setter */
let signal: 'a => (s<'a>, 'a => unit)

/** Syntax sugar to create a derived signal */
let derived: (unit => 'a) => s<'a>

/** Syntax sugar to create a state machine: the update function receives
 * the current value and a setter.
 */
let update: ('a, ('a, 'a => unit) => unit) => s<'a>

/** Internal types for library developers (global context) */
/** internal */
let _observe: (unit => unit) => observer
/** internal */
let _ready: (observer, bool) => unit
/** Dispose of an observer */
let _clear: observer => unit
/** Get meta information (mostly for stats) */
let _meta: 'a => nullable<meta<'a>>
