import { filterKey } from "@feature/todos/actions/_utils";
import type { RepoReady } from "@interface/repo";
import type { Todos, TodosFilter } from "@interface/todos";

export function setFilter(repo: RepoReady, todos: Todos, filter: TodosFilter) {
  todos.filter = filter;
  repo.saveSetting(filterKey, filter);
}
