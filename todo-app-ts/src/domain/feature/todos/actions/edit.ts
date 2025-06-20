import type { Todos } from "@feature/todos";
import { newTodo } from "./_utils";

export function edit(todos: Todos, id: string) {
  const todo = todos.list.find((t) => t.id === id);
  if (!todo) {
    throw new Error(`Todo ${JSON.stringify(id)} not found`);
  }
  if (id === todos.selected.id) {
    todos.selected = newTodo();
  } else {
    todos.selected = todo;
  }
}
