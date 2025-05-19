import { filterKey } from "@feature/todos/actions/_utils";
import type { Repo } from "@interface/repo";
import type { Todos, TodosFilter } from "@interface/todos";

export function setFilter(repo: Repo, todos: Todos, filter: TodosFilter) {
  todos.filter = filter;
  repo.saveSetting(filterKey, filter);
}
