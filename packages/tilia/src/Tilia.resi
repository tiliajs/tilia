type observer
type root
type t<'a> = (root, 'a)
let make: 'a => t<'a>
let _connect: (t<'a>, unit => unit) => observer
let _flush: observer => unit
let observe: (t<'a>, 'a => unit) => unit
