open Tilia
let useTilia: unit => unit
/** Create a useTilia hook from (_observe, _ready, _clear) */
let makeUseTilia: (
  (unit => unit) => observer,
  (observer, bool) => unit,
  observer => unit,
) => unit => unit
