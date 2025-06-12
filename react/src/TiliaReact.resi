open Tilia
type tilia_react = {
  useTilia: unit => unit,
  useComputed: 'a. (unit => 'a) => signal<'a>,
}

let useTilia: unit => unit
let useComputed: (unit => 'a) => signal<'a>

/** 
 * Create api from a tilia context.
*/
let make: tilia => tilia_react
