import type { Todos } from "@feature/todos";

export function setTitle(todos: Todos, title: string) {
  todos.selected.title = title;
}
