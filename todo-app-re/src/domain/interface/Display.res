type s = {mutable darkMode: bool}

type t = {
  // State
  s: s,
  // Operations
  setDarkMode: bool => promise<result<bool, string>>,
}
