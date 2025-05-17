import { connect, observe } from "./tilia";
import type { Display, Filters } from "./types/display";
import { isFail, isReady, isSuccess, success, type Store } from "./types/store";

export function makeDisplay(store: Store) {
  const display: Display = connect({
    filters: {
      todos: "all",
    },
    setFilters: async (filters: Filters) => {
      const result = await store.saveFilters(filters);
      if (isFail(result)) {
        return result;
      }
      display.filters = filters;
      return success(filters);
    },
  });

  observe(() => {
    if (isReady(store)) {
      fetchFilters(display.filters, store);
    }
  });

  return display;
}

async function fetchFilters(filters: Filters, store: Store) {
  const result = await store.fetchFilters();
  if (isSuccess(result)) {
    filters.todos = result.value.todos;
  }
}
