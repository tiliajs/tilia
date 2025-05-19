type state =
  | NotAuthenticated
  | Opening
  | Ready
  | Error(string)

type s = {mutable state: state}

type t = {
  // State
  t: s,
  // Operations
  saveTodo: Todo.t => promise<result<Todo.t, string>>,
  removeTodo: string => promise<result<string, string>>,
  fetchTodos: string => promise<result<array<Todo.t>, string>>,
  saveSetting: (string, string) => promise<result<string, string>>,
  fetchSetting: string => promise<result<string, string>>,
}
