import type { Display } from "../ports/display";
import {
  isFail,
  isReady,
  isSuccess,
  success,
  type Store,
} from "../ports/store";
import { type Context } from "../tilia";

const darkModeKey = "display.darkMode";

export function makeDisplay({ connect, observe }: Context, store: Store) {
  const display: Display = connect({
    darkMode: false,

    // Operations
    setDarkMode: async (darkMode: boolean) => {
      const result = await store.saveSetting(
        darkModeKey,
        darkMode ? "true" : "false"
      );
      if (isFail(result)) {
        return result;
      }
      display.darkMode = darkMode;
      return success(darkMode);
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
  const result = await store.fetchSetting(darkModeKey);
  if (isSuccess(result)) {
    display.darkMode = result.value === "true";
  }
}
