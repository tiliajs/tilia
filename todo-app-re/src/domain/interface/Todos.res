// Import types from other modules
// In ReScript, you typically use `@module` for JS interop, but for type-only imports, just reference the types directly
// Assume Loadable, Void, and Todo are defined in their respective modules

module Filter = {
  type t =
    | All
    | Active
    | Completed

  // List of possible filter values
  let values: array<t> = [All, Active, Completed]

  let toString = filter =>
    switch filter {
    | All => "all"
    | Active => "active"
    | Completed => "completed"
    }

  let ofString = str =>
    switch str {
    | "all" => Some(All)
    | "active" => Some(Active)
    | "completed" => Some(Completed)
    | _ => None
    }
}

// Todos port (contract)
type s = {
  // State
  mutable filter: Filter.t,
  mutable selected: Todo.t,
  // Computed state
  mutable data: Loadable.t<array<Todo.t>>,
  mutable list: array<Todo.t>,
  mutable remaining: int,
}

type t = {
  s: s,
  // Operations
  clear: unit => unit,
  edit: Todo.t => unit,
  remove: string => promise<unit>,
  save: Todo.t => promise<unit>,
  setFilter: Filter.t => promise<unit>,
  setTitle: string => promise<unit>,
  toggle: string => promise<unit>,
}
