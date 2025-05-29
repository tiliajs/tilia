import type { Todos } from "src/domain/api/feature/todos";
import { newTodo } from "./_utils";

export function clear(todos: Todos) {
  todos.selected = newTodo();
}
