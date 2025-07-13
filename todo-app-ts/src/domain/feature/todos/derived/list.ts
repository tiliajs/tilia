import type { Todo } from "@entity/todo";
import type { Todos, TodosFilter } from "@feature/todos";

export function list(todos: Todos): Todo[] {
  return (
    todos.data
      .filter(listFilter(todos.filter))
      // Filter produces a new array, we can sort in place
      .sort((a, b) => (b.createdAt > a.createdAt ? 1 : -1))
  );
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
