import { isLoaded } from "@entity/loadable";
import type { Todo } from "@entity/todo";
import type { Todos, TodosFilter } from "@feature/todos";

export function list(todos: Todos): Todo[] {
  const {
    data_: { value: data },
  } = todos;
  if (isLoaded(data)) {
    return (
      data.value
        // Filter produces a new array, we can sort in place
        .filter(listFilter(todos.filter))
        .sort((a, b) => (b.createdAt > a.createdAt ? 1 : -1))
    );
  }
  return [];
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
