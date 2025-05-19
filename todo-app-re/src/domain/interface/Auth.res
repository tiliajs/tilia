type state =
  | NotAuthenticated
  | Authenticating
  | Authenticated(User.t)

type s = {
  // State
  mutable auth: state,
}

type t = {
  // State
  s: s,
  // Operations
  login: User.t => unit,
  logout: unit => unit,
}
