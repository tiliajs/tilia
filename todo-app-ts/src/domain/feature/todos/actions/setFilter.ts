import type { Todos, TodosFilter } from "@feature/todos";
import { filterKey } from "./_utils";

export function setFilter(todos: Todos) {
  return (filter: TodosFilter) => {
    todos.filter = filter;
    todos.repo.saveSetting(filterKey, filter);
  };
}
