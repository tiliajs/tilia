import { filterKey } from "@feature/todos/actions/_utils";
import { isReady, isSuccess, type Store } from "@interface/store";
import type { Todos, TodosFilter } from "@interface/todos";

export function fetchFilterOnReady(store: Store, todos: Todos) {
  if (isReady(store)) {
    fetchFilter(todos, store);
  }
}

// ======= PRIVATE ========================

async function fetchFilter(todos: Todos, store: Store) {
  const result = await store.fetchSetting(filterKey);
  if (isSuccess(result)) {
    todos.filter = result.value as TodosFilter;
  }
}
