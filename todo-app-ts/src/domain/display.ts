import { connect, observe } from "./tilia";
import type { Display, Settings } from "./types/display";
import { isFail, isReady, isSuccess, success, type Store } from "./types/store";

export function makeDisplay(store: Store) {
  const display: Display = connect({
    settings: {
      todos: "all",
      darkMode: false,
    },

    // Operations
    setFilters: async (filters: Settings) => {
      const result = await store.saveSettings(filters);
      if (isFail(result)) {
        return result;
      }
      display.settings = filters;
      return success(filters);
    },
  });

  observe(() => {
    if (isReady(store)) {
      fetchFilters(display.settings, store);
    }
  });

  return display;
}

async function fetchFilters(filters: Settings, store: Store) {
  const result = await store.fetchSettings();
  if (isSuccess(result)) {
    filters.todos = result.value.todos;
  }
}
