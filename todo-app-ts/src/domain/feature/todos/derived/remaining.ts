import type { Todos } from "@feature/todos";

export function remaining(todos: Todos): number {
  return todos.data.filter((t) => !t.completed).length;
}
