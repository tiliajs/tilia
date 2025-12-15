open Tilia

@genType
type todo = {
  id: string,
  title: string,
  mutable completed: bool,
}

@genType
type todos = {
  mutable list: array<todo>,
  add: todo => unit,
  toggle: string => unit,
  remove: string => unit,
  completedCount: int,
}

@genType
let makeTodo = (id: string, title: string): todo => {
  {id, title, completed: false}
}

let add = self => (todo: todo) => {
  self.list->Array.push(todo)
}

let toggle = self => id =>
  switch self.list->Array.find(t => t.id == id) {
  | None => ()
  | Some(t) =>
    // You can mutate in place.
    t.completed = !t.completed
  }

let remove = self => id => {
  self.list = self.list->Array.filter(todo => todo.id != id)
}

let completedCount = self => self.list->Array.filter(todo => todo.completed)->Array.length

@genType
let make = () =>
  carve(({derived}) => {
    list: [],
    add: derived(add),
    toggle: derived(toggle),
    remove: derived(remove),
    completedCount: derived(completedCount),
  })
