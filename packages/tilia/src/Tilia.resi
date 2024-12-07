type observer
type t
let init: 'a => (t, 'a)
let connect: (t, unit => unit) => observer
let flush: observer => unit
let clear: observer => unit
// let observe: ((t, 'a), 'a => unit) => observer
