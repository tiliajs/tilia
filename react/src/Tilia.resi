type observer = TiliaCore.observer
let make: ('a, ~flush: (unit => unit) => unit=?) => 'a
let observe: ('a, 'a => unit) => unit
let computed: (unit => 'a) => 'a
let track: ('a, 'a => unit) => observer
let clear: observer => unit

let use: 'a => 'a
