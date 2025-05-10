type observer
type root
type meta<'a>
type computed<'p, 'a> = ('a, 'p => 'a) => 'a
type tilia

/** Create a new tilia context and returns a connect function to create tilia
 * proxies.  The default flush function is set to a timeout of 0 (after the
 * current event loop). 
 */
let tilia: (~flush: (unit => unit) => unit=?) => tilia
let connect: (tilia, 'a) => 'a

/** Runs a callback with the given object as the current target. The callback
 * is called whenever any observed value changes. This is a PUSH model: the
 * callback is called on the next flush.
 *
 * See "signal" for a PULL model where the callback is only called on object read.
 * 
 * See "track" for another PUSH model where the callback is called on any change
 * in the observed branch (the callback is not used to build the dependency graph).
 */
let observe: ('a, 'a => unit) => unit

/** React to any change in the observed branch. 
  */
let track: ('a, 'a => unit) => observer

/** Stop tracking. 
  */
let clear: observer => unit

/** Internal types for library developers */
/** internal */
let _connect: ('a, unit => unit) => observer
/** internal */
let _ready: (observer, ~notifyIfChanged: bool=?) => unit
/** internal */
let _meta: 'a => meta<'a>

/* Computed (pseudo-signals) */

/** Return a computed value to be inserted into a tilia proxy. The cached value
 * is computed when the key is read and destroyed when any observed value is
 * changed.
 */
let computed: ('a, 'p => 'a) => 'a
