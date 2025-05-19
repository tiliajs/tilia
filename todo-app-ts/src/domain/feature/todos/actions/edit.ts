import type { Todos } from "@interface/todos";
import type { Todo } from "@model/todo";
import { newTodo } from "./_utils";

export function edit(todos: Todos, todo: Todo) {
  if (todo === todos.selected) {
    todos.selected = newTodo();
  } else {
    todos.selected = todo;
  }
}
