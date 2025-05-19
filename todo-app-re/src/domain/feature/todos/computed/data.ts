import { isAuthenticated, type Auth } from "@interface/auth";
import { isReady, isSuccess, type Repo } from "@interface/repo";
import type { Todos } from "@interface/todos";
import { blank, loaded, loading, type Loadable } from "@model/loadable";
import type { Todo } from "@model/todo";

export function data(
  { auth }: Auth,
  repo: Repo,
  todos: Todos
): Loadable<Todo[]> {
  if (isAuthenticated(auth) && isReady(repo)) {
    loadTodos(todos, repo.fetchTodos, auth.user.id);
    return loading();
  } else {
    return blank();
  }
}

// ======= PRIVATE ========================

async function loadTodos(
  todos: Todos,
  fetchTodos: Repo["fetchTodos"],
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
