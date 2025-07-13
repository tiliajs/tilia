import type { Todos } from "@feature/todos";

export function setTitle(todos: Todos) {
  return (title: string) => {
    todos.selected.title = title;
  };
}
