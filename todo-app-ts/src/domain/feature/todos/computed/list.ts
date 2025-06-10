import type { Todos, TodosFilter } from "src/domain/api/feature/todos";
import {
  blank,
  isLoaded,
  loaded,
  loading,
  type Loadable,
} from "src/domain/api/model/loadable";
import type { Todo } from "src/domain/api/model/todo";

export function list(todos: Todos): Loadable<Todo[]> {
  const {
    data_: { value: data },
  } = todos;
  if (isLoaded(data)) {
    const l = data.value
      .filter(listFilter(todos.filter))
      .sort((a, b) => (b.createdAt > a.createdAt ? 1 : -1));
    return loaded(l);
  } else if (data.t === "Blank") {
    return blank();
  }
  return loading();
}

// ======= PRIVATE ========================

function listFilter(filter: TodosFilter): (todo: Todo) => boolean {
  switch (filter) {
    case "active":
      return (f: Todo) => f.completed === false;
    case "completed":
      return (f: Todo) => f.completed === true;
    default:
      return (_: Todo) => true;
  }
}
