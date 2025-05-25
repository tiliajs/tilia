import { isSuccess, type RepoReady } from "@interface/repo";
import type { Todos } from "@interface/todos";
import { blank, loaded, loading, type Loadable } from "@model/loadable";
import type { Todo } from "@model/todo";

export function data(repo: RepoReady, todos: Todos): Loadable<Todo[]> {
  loadTodos(todos, repo.fetchTodos);
  return loading();
}

// ======= PRIVATE ========================

async function loadTodos(todos: Todos, fetchTodos: RepoReady["fetchTodos"]) {
  const data = await fetchTodos();
  console.log("data", data);
  if (isSuccess(data)) {
    todos.data = loaded(data.value);
  } else {
    // Error already handled by the store
    todos.data = blank();
  }
}
