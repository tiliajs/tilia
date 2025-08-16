open Tilia
type tilia_react = {
  useTilia: unit => unit,
  useComputed: 'a. (unit => 'a) => 'a,
  leaf: 'a 'b. ('a => 'b) => 'a => 'b,
}

let useTilia: unit => unit
let useComputed: (unit => 'a) => 'a
let leaf: ('a => 'b) => 'a => 'b

/** 
 * Create api from a tilia context.
*/
let make: tilia => tilia_react
