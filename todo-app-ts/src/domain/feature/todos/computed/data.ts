import {
  blank,
  loaded,
  loading,
  type Loadable,
} from "src/domain/api/model/loadable";
import type { Todo } from "src/domain/api/model/todo";
import { isSuccess, type RepoReady } from "src/domain/api/service/repo";
import type { Setter } from "tilia";

export function data(
  set: Setter<Loadable<Todo[]>>,
  repo: RepoReady
): Loadable<Todo[]> {
  loadTodos(set, repo.fetchTodos);
  return loading();
}

// ======= PRIVATE ========================

async function loadTodos(
  set: Setter<Loadable<Todo[]>>,
  fetchTodos: RepoReady["fetchTodos"]
) {
  const data = await fetchTodos();
  if (isSuccess(data)) {
    set(loaded(data.value));
  } else {
    // Error already handled by the store
    set(blank());
  }
}
