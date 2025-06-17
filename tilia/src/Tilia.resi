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
  batch: (unit => unit) => unit,
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
 * The gc parameter is the number of cleared watchers to keep before triggering a GC (default is 50).
 */
let make: (~gc: int=?) => tilia

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

let batch: (unit => unit) => unit

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
