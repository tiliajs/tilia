type observer
type meta<'a>

type t<'a> = {
  /** Create a new tilia proxy and connect it to the forest.
   */
  connect: 'a. 'a => 'a,
  /** Re-runs a callback whenever any of the observed values changes. 
   * The observer implements a PUSH model (changes "push" the callback to run).
   *
   * See "computed" for a PULL model where the callback is only called when the
   * produced value is read.
   */
  observe: (unit => unit) => unit,
  /** Return a computed value to be inserted into a tilia proxy. The cached value
   * is computed when the key is read and destroyed when any observed value is
   * changed.
   * 
   * The first parameter to the callback is the "connected" object.
   */
  computed: 'b. ('a => 'b) => 'b,
  /** Move the state of a proxy object to a new state. The callback should return
   * the new state of the proxy object. This is more idiomatic for ReScript.
   */
  update: 'a. ('a, unit => 'a) => unit,
  /** Move the state of a proxy object to a new state using a setter callback.
   * The callback can be used in an async function (outside of the move callback).
   * This is more idiomatic for TypeScript.
   */
  move: 'a. ('a, ('a => unit) => unit) => unit,
}

/** Create a new tilia context and returns the `connect` and `observe` functions.
 * The default flush function is set to notify on the next event loop (setTimeout).
 */
let make: (~flush: (unit => unit) => unit=?) => t<'a>

/** Internal types for library developers */
/** internal */
let _observe: ('a, unit => unit) => observer
/** internal */
let _ready: (observer, ~notifyIfChanged: bool=?) => unit
/** internal */
let _meta: 'a => meta<'a>
/** Dispose of an observer */
let _clear: observer => unit
