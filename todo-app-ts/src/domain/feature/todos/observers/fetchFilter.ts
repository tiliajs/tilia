import { filterKey } from "@feature/todos/actions/_utils";
import { isSuccess, type Repo, type RepoReady } from "@interface/repo";
import type { Todos, TodosFilter } from "@interface/todos";

export function fetchFilterOnReady(repo: Repo, todos: Todos) {
  if (repo.t === "Ready") {
    fetchFilter(repo, todos);
  }
}

// ======= PRIVATE ========================

async function fetchFilter(repo: RepoReady, todos: Todos) {
  const result = await repo.fetchSetting(filterKey);
  if (isSuccess(result)) {
    todos.filter = result.value as TodosFilter;
  }
}
