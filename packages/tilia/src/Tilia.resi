type observer
type t
let init: 'a => (t, 'a)
let connect: (t, unit => unit) => observer
let flush: (t, observer) => unit
let clear: (t, observer) => unit
// let observe: ('a, 'a => unit) => t
