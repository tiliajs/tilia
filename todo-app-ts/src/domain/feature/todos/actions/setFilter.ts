import { filterKey } from "@feature/todos/actions/_utils";
import type { Store } from "@interface/store";
import type { Todos, TodosFilter } from "@interface/todos";

export function setFilter(store: Store, todos: Todos, filter: TodosFilter) {
  todos.filter = filter;
  store.saveSetting(filterKey, filter);
}
