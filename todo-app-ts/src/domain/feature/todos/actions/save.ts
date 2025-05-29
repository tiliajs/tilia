import { newTodo } from "@feature/todos/actions/_utils";
import type { Todos } from "src/domain/api/feature/todos";
import { isLoaded } from "src/domain/api/model/loadable";
import type { Todo } from "src/domain/api/model/todo";
import { isSuccess, type RepoReady } from "src/domain/api/service/repo";
import { v4 as uuid } from "uuid";

export async function save(repo: RepoReady, todos: Todos, atodo: Todo) {
  if (isLoaded(todos.data)) {
    const isNew = atodo.id === "";
    const todo = { ...atodo };
    if (todo.title === "") {
      return;
    }
    if (isNew) {
      todo.createdAt = new Date().toISOString();
      todo.id = uuid();
    }
    todos.selected = newTodo();
    const result = await repo.saveTodo(todo);
    if (isSuccess(result)) {
      const todo = result.value;
      if (isNew) {
        todos.data.value.push(todo);
      } else {
        // mutate in place
        Object.assign(todo, result.value);
      }
    } else {
      throw new Error(`Cannot save (${result.message})`);
    }
  } else {
    throw new Error("Cannot save (data not yet loaded)");
  }
}
