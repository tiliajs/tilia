type observer
type root
type t<'a> = (root, 'a)
let init: 'a => t<'a>
let connect: (t<'a>, unit => unit) => observer
let flush: observer => unit
let clear: observer => unit
// let observe: (t<'a>, 'a => unit) => observer
