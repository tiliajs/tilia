import type { Todos } from "src/domain/api/feature/todos";
import type { Todo } from "src/domain/api/model/todo";
import { newTodo } from "./_utils";

export function edit(todos: Todos, todo: Todo) {
  if (todo === todos.selected) {
    todos.selected = newTodo();
  } else {
    todos.selected = todo;
  }
}
