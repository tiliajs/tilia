import { filterKey } from "@feature/todos/actions/_utils";
import { isReady, isSuccess, type Repo } from "@interface/repo";
import type { Todos, TodosFilter } from "@interface/todos";

export function fetchFilterOnReady(repo: Repo, todos: Todos) {
  if (isReady(repo)) {
    fetchFilter(repo, todos);
  }
}

// ======= PRIVATE ========================

async function fetchFilter(repo: Repo, todos: Todos) {
  const result = await repo.fetchSetting(filterKey);
  if (isSuccess(result)) {
    todos.filter = result.value as TodosFilter;
  }
}
