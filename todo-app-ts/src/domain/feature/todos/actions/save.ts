import type { Todos } from "@feature/todos";
import { isLoaded } from "@model/loadable";
import type { Todo } from "@model/todo";
import { isSuccess, type RepoReady } from "@service/repo";
import { v4 as uuid } from "uuid";
import { newTodo } from "./_utils";

export async function save(repo: RepoReady, todos: Todos, atodo: Todo) {
  const data = todos.data_.value;
  if (isLoaded(data)) {
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
        data.value.push(todo);
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
