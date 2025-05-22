import { type AuthAuthenticated } from "@interface/auth";
import { isSuccess, type RepoReady } from "@interface/repo";
import type { Todos } from "@interface/todos";
import { blank, loaded, loading, type Loadable } from "@model/loadable";
import type { Todo } from "@model/todo";

export function data(
  auth: AuthAuthenticated,
  repo: RepoReady,
  todos: Todos
): Loadable<Todo[]> {
  if (auth.t === "Authenticated") {
    loadTodos(todos, repo.fetchTodos, auth.user.id);
    return loading();
  } else {
    return blank();
  }
}

// ======= PRIVATE ========================

async function loadTodos(
  todos: Todos,
  fetchTodos: RepoReady["fetchTodos"],
  userId: string
) {
  const data = await fetchTodos(userId);
  if (isSuccess(data)) {
    todos.data = loaded(data.value);
  } else {
    // Error already handled by the store
    todos.data = blank();
  }
}
