import type { Todo } from "@entity/todo";
import type { Todos } from "@feature/todos";
import { isSuccess } from "@service/repo";
import { v4 as uuid } from "uuid";
import { newTodo } from "./_utils";

export function save(todos: Todos) {
  return async (atodo: Todo) => {
    const { data, repo } = todos;

    const isNew = atodo.id === "";
    const todo = { ...atodo };
    if (todo.title === "") {
      return;
    }
    if (isNew) {
      todo.createdAt = new Date().toISOString();
      todo.id = uuid();
    }
    if (todos.selected.id === atodo.id) {
      todos.selected = newTodo();
    }
    const result = await repo.saveTodo(todo);
    if (isSuccess(result)) {
      const todo = result.value;
      if (isNew) {
        data.push(todo);
      } else {
        // mutate in place
        Object.assign(todo, result.value);
      }
    } else {
      throw new Error(`Cannot save (${result.message})`);
    }
  };
}
