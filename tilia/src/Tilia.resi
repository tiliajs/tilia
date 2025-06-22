type observer

type signal<'a> = {mutable value: 'a}
type readonly<'a> = {value: 'a}
type setter<'a> = 'a => unit

type tilia = {
  /** 
   * Transform a regular object or array into a tilia proxy value.
   * 
   * The returned value is reactive: any nested fields or elements are tracked for changes.
   */
  tilia: 'a. 'a => 'a,
  /** 
   * Register a callback to be re-run whenever any observed value changes in the default context.
   * 
   * This uses a PUSH model: changes "push" the callback to run.
   * 
   * For a PULL model (run only when a value is read), see `computed`.
   */
  observe: (unit => unit) => unit,
  /** 
   * Run a series of operations in a batch, blocking notifications until the batch is complete.
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
 * Register a callback to be re-run whenever any of the observed values changes.
 * 
 * This uses a PUSH model: changes "push" the callback to run.  For a PULL model
 * (run only when a value is read), see `computed`.
 * 
 * @param f The callback to run on changes.
 */
let observe: (unit => unit) => unit

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
let source: (('a => unit) => unit, 'a) => 'a

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
