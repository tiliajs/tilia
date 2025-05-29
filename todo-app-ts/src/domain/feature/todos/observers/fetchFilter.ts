import { filterKey } from "@feature/todos/actions/_utils";
import type { Todos, TodosFilter } from "src/domain/api/feature/todos";
import {
  isSuccess,
  type Repo,
  type RepoReady,
} from "src/domain/api/service/repo";

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
