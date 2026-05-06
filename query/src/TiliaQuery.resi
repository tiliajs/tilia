type loadable<'a> =
  | Loading
  | Loaded('a)
  | NotFound

type t<'a> = {
  get: string => loadable<'a>,
  find: string => loadable<array<string>>,
}

let make: (~id: 'a => string, ~fetch: string => promise<array<'a>>, unit) => t<'a>

let toArray: t<'a> => loadable<array<string>> => loadable<array<'a>>
