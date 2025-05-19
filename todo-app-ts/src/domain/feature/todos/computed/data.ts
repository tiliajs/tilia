import { isAuthenticated, type Auth } from "@interface/auth";
import { isReady, isSuccess, type Store } from "@interface/store";
import type { Todos } from "@interface/todos";
import { blank, loaded, loading, type Loadable } from "@model/loadable";
import type { Todo } from "@model/todo";

export function data(
  { auth }: Auth,
  store: Store,
  todos: Todos
): Loadable<Todo[]> {
  if (isAuthenticated(auth) && isReady(store)) {
    loadTodos(todos, store.fetchTodos, auth.user.id);
    return loading();
  } else {
    return blank();
  }
}

// ======= PRIVATE ========================

async function loadTodos(
  todos: Todos,
  fetchTodos: Store["fetchTodos"],
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
