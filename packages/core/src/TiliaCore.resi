type observer
type root
type meta<'a>

let make: 'a => 'a
let observe: ('a, 'a => unit) => unit

/** Internal types for library developers */
/** internal */
let _connect: ('a, unit => unit, ~notifyIfChanged: bool=?) => observer
/** internal */
let _ready: observer => unit
/** internal */
let _clear: observer => unit
/** internal */
let _meta: 'a => meta<'a>
