import type { Display, Settings } from "../ports/display";
import {
  isFail,
  isReady,
  isSuccess,
  success,
  type Store,
} from "../ports/store";
import { type Context } from "../tilia";

export function makeDisplay({ connect, observe }: Context, store: Store) {
  const display: Display = connect({
    settings: {
      todos: "all",
      darkMode: false,
    },

    // Operations
    setSettings: async (settings: Settings) => {
      const result = await store.saveSettings(settings);
      if (isFail(result)) {
        return result;
      }
      display.settings = settings;
      return success(settings);
    },
  });

  observe(() => {
    if (isReady(store)) {
      fetchSettings(display, store);
    }
  });

  return display;
}

async function fetchSettings(display: Display, store: Store) {
  const result = await store.fetchSettings();
  if (isSuccess(result)) {
    Object.assign(display.settings, result.value);
  }
}
