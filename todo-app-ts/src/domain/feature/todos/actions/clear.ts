import type { Todos } from "@feature/todos";
import { newTodo } from "./_utils";

export function clear(todos: Todos) {
  return () => {
    todos.selected = newTodo();
  };
}
