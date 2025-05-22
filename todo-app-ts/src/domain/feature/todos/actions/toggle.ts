import { saveTodo } from "@feature/todos/actions/_utils";
import type { AuthAuthenticated } from "@interface/auth";
import type { RepoReady } from "@interface/repo";
import type { Todos } from "@interface/todos";
import { isLoaded } from "@model/loadable";

export function toggle(
  auth: AuthAuthenticated,
  repo: RepoReady,
  todos: Todos,
  id: string
) {
  if (isLoaded(todos.data)) {
    const todo = todos.data.value.find((t) => t.id === id);
    if (todo) {
      todo.completed = !todo.completed;
      saveTodo(auth, repo, todo);
    }
  }
}
