import type { Todos } from "@interface/todos";

export function setTitle(todos: Todos, title: string) {
  todos.selected.title = title;
}
