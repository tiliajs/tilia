import type { Todos, TodosFilter } from "@feature/todos";
import { isSuccess, type Repo, type RepoReady } from "@service/repo";
import { filterKey } from "../actions/_utils";

export function fetchFilterOnReady(repo: Repo, todos: Todos) {
  if (repo.t === "Ready") {
    fetchFilter(repo, todos);
  }
}

// ======= PRIVATE ========================

async function fetchFilter(repo: RepoReady, todos: Todos) {
  const result = await repo.fetchSetting(filterKey);
  if (isSuccess(result)) {
    todos.setFilter(result.value as TodosFilter);
  }
}
