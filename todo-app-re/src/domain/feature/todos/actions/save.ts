import { newTodo, saveTodo } from "@feature/todos/actions/_utils";
import type { Auth } from "@interface/auth";
import { isSuccess, type Repo } from "@interface/repo";
import type { Todos } from "@interface/todos";
import { isLoaded } from "@model/loadable";
import type { Todo } from "@model/todo";
import { v4 as uuid } from "uuid";

export async function save(auth: Auth, repo: Repo, todos: Todos, atodo: Todo) {
  if (isLoaded(todos.data)) {
    const isNew = atodo.id === "";
    const todo = { ...atodo };
    if (isNew) {
      todo.createdAt = new Date().toISOString();
      todo.id = uuid();
    }
    todos.selected = newTodo();
    const result = await saveTodo(auth, repo, todo);
    if (isSuccess(result)) {
      const todo = result.value;
      if (isNew) {
        todos.data.value.push(todo);
      } else {
        // mutate in place
        Object.assign(todo, result.value);
      }
      return todo;
    } else {
      throw new Error(`Cannot save (${result.message})`);
    }
  } else {
    throw new Error("Cannot save (data not yet loaded)");
  }
}
