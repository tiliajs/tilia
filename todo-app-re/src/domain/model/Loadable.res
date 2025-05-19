type t<'t> =
  | Blank
  | Loading
  | Loaded('t)
