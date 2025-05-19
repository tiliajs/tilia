open Todo
open Todos
open Loadable

@module("uuid") external uuid: unit => string = "v4"

@val external assign: ('a, 'a) => unit = "Object.assign"

// === Utilities ===

let filterKey = "todos.filter"

let newTodo = () => {
  id: "",
  createdAt: "",
  // userId is set on save.
  userId: "",
  title: "",
  completed: false,
}

let saveTodo = async (auth: Auth.t, repo, todo) =>
  switch auth.s.auth {
  | Authenticated(user) => await repo.Repo.saveTodo({...todo, userId: user.id})
  | _ => Error("Not authenticated")
  }

// === Computed ===

let loadTodos = async (todos: Todos.s, repo: Repo.t, userId: string) => {
  switch await repo.fetchTodos(userId) {
  | Ok(data) => todos.data = Loaded(data)
  | _ => todos.data = Blank
  }
}

let data = (auth: Auth.t, repo: Repo.t, todos: Todos.s) => () => {
  switch (auth.s.auth, repo.t.state) {
  | (Authenticated(user), Ready) => {
      ignore(loadTodos(todos, repo, user.id))
      Loading
    }
  | _ => Blank
  }
}

let listFilter = filter => {
  switch filter {
  | Filter.Active => t => t.completed == false
  | Completed => t => t.completed == true
  | _ => _ => true
  }
}

let list = todos => () => {
  switch todos.data {
  | Loaded(data) =>
    data
    ->Array.filter(listFilter(todos.filter))
    ->Array.toSorted((a, b) => a.createdAt->String.compare(b.createdAt))
  | _ => []
  }
}

// === Computed ===

let fetchFilter = async (repo, todos) =>
  switch await repo.Repo.fetchSetting(filterKey) {
  | Ok(filter) =>
    switch Filter.ofString(filter) {
    | Some(filter) => todos.filter = filter
    | None => todos.filter = All
    }
  | _ => ()
  }

// === Operations ===

let save = (auth, repo, todos: Todos.s) => async todo =>
  switch todos.data {
  | Loaded(data) =>
    switch todo.id {
    | "" =>
      switch await saveTodo(auth, repo, {...todo, id: uuid()}) {
      | Ok(todo) => data->Array.push(todo)
      | _ => Js.Exn.raiseError("Could not save todo.")
      }
    | _ =>
      switch await saveTodo(auth, repo, todo) {
      | Ok(t) => assign(todo, t)
      | _ => Js.Exn.raiseError("Could not save todo.")
      }
    }
  | _ => Js.Exn.raiseError("Cannot save (data not yet loaded)")
  }

let setFilter = (repo, todos) => async filter => {
  todos.filter = filter
  ignore(repo.Repo.saveSetting(filterKey, filter->Filter.toString))
}

let setTitle = todos => async title => {
  todos.selected.title = title
}

let toggle = (auth, repo, todos) => async id => {
  switch todos.data {
  | Loaded(data) =>
    switch data->Array.find(t => t.id == id) {
    | Some(todo) =>
      todo.completed = !todo.completed
      ignore(saveTodo(auth, repo, todo))
    | None => ()
    }
  | _ => ()
  }
}

// === Make ===

let make = ({connect, computed, observe}: Tilia.t<'a>, auth: Auth.t, repo: Repo.t) => {
  let s = connect({
    // State
    filter: All,
    selected: newTodo(),
    // Computed state
    data: Blank,
    list: [],
    remaining: 0,
  })
  s.data = computed(data(auth, repo, s))
  s.list = computed(list(s))

  observe(() =>
    switch repo.t.state {
    | Ready => ignore(fetchFilter(repo, s))
    | _ => ()
    }
  )

  {
    // State
    s,
    // Actions
    clear: () => s.selected = newTodo(),
    edit: todo => s.selected = todo,
    remove: async id =>
      switch s.data {
      | Loaded(data) =>
        switch await repo.removeTodo(id) {
        | Ok(id) => s.data = Loaded(data->Array.filter(t => t.id !== id))
        | _ => ()
        }
      | _ => ()
      },
    save: save(auth, repo, s),
    setFilter: setFilter(repo, s),
    setTitle: setTitle(s),
    toggle: toggle(auth, repo, s),
  }
}
