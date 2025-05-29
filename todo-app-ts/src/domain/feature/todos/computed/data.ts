import type { Todos } from "src/domain/api/feature/todos";
import {
  blank,
  loaded,
  loading,
  type Loadable,
} from "src/domain/api/model/loadable";
import type { Todo } from "src/domain/api/model/todo";
import { isSuccess, type RepoReady } from "src/domain/api/service/repo";

export function data(repo: RepoReady, todos: Todos): Loadable<Todo[]> {
  loadTodos(todos, repo.fetchTodos);
  return loading();
}

// ======= PRIVATE ========================

async function loadTodos(todos: Todos, fetchTodos: RepoReady["fetchTodos"]) {
  const data = await fetchTodos();
  if (isSuccess(data)) {
    todos.data = loaded(data.value);
  } else {
    // Error already handled by the store
    todos.data = blank();
  }
}
