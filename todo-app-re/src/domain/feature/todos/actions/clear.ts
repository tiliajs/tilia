import type { Todos } from "@interface/todos";
import { newTodo } from "./_utils";

export function clear(todos: Todos) {
  todos.selected = newTodo();
}
