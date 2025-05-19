import { saveTodo } from "@feature/todos/actions/_utils";
import type { Auth } from "@interface/auth";
import type { Repo } from "@interface/repo";
import type { Todos } from "@interface/todos";
import { isLoaded } from "@model/loadable";

export function toggle(auth: Auth, repo: Repo, todos: Todos, id: string) {
  if (isLoaded(todos.data)) {
    const todo = todos.data.value.find((t) => t.id === id);
    if (todo) {
      todo.completed = !todo.completed;
      saveTodo(auth, repo, todo);
    }
  }
}
