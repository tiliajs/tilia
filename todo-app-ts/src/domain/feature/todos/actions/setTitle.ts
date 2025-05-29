import type { Todos } from "src/domain/api/feature/todos";

export function setTitle(todos: Todos, title: string) {
  todos.selected.title = title;
}
