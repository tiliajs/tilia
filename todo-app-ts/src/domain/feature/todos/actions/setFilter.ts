import { filterKey } from "@feature/todos/actions/_utils";
import type { Todos, TodosFilter } from "src/domain/api/feature/todos";
import type { RepoReady } from "src/domain/api/service/repo";

export function setFilter(repo: RepoReady, todos: Todos, filter: TodosFilter) {
  todos.filter = filter;
  repo.saveSetting(filterKey, filter);
}
