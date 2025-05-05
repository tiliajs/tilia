type observer = TiliaCore.observer
let make: ('a, ~flush: (unit => unit) => unit=?) => 'a
let observe: ('a, 'a => unit) => unit
let compute: ('a, string, 'a => unit) => observer
let track: ('a, 'a => unit) => observer
let clear: observer => unit

let use: 'a => 'a
