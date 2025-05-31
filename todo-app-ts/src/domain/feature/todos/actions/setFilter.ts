import type { Todos, TodosFilter } from "@feature/todos";
import type { RepoReady } from "@service/repo";
import { filterKey } from "./_utils";

export function setFilter(repo: RepoReady, todos: Todos, filter: TodosFilter) {
  todos.filter = filter;
  repo.saveSetting(filterKey, filter);
}
