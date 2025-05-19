import type { Tilia } from "tilia";
import type { Display } from "../interface/display";
import {
  isFail,
  isReady,
  isSuccess,
  success,
  type Repo,
} from "../interface/repo";

const darkModeKey = "display.darkMode";

export function makeDisplay({ connect, observe }: Tilia, repo: Repo) {
  const display: Display = connect({
    darkMode: false,

    // Operations
    setDarkMode: async (darkMode: boolean) => {
      const result = await repo.saveSetting(
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
    if (isReady(repo)) {
      fetchSettings(repo, display);
    }
  });

  return display;
}

async function fetchSettings(repo: Repo, display: Display) {
  const result = await repo.fetchSetting(darkModeKey);
  if (isSuccess(result)) {
    display.darkMode = result.value === "true";
  }
}
