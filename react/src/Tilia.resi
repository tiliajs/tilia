type observer = TiliaCore.observer
let make: 'a => 'a
let observe: ('a, 'a => unit) => unit
let track: ('a, 'a => unit) => observer
let clear: observer => unit

let use: 'a => 'a
