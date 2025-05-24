import { connect, observe, type Signal } from "tilia";
import type { Display } from "../interface/display";
import {
  isFail,
  isSuccess,
  success,
  type Repo,
  type RepoReady,
} from "../interface/repo";

const darkModeKey = "display.darkMode";

export function makeDisplay(repo_: Signal<Repo>) {
  const display: Display = connect({
    darkMode: false,

    // Operations
    setDarkMode: async (darkMode: boolean) => {
      const repo = repo_.value;
      if (repo.t === "Ready") {
        const result = await repo.saveSetting(
          darkModeKey,
          darkMode ? "true" : "false"
        );
        if (isFail(result)) {
          return result;
        }
      }
      display.darkMode = darkMode;
      return success(darkMode);
    },
  });

  observe(() => {
    const repo = repo_.value;
    if (repo.t === "Ready") {
      fetchSettings(repo, display);
    }
  });

  return display;
}

async function fetchSettings(repo: RepoReady, display: Display) {
  const result = await repo.fetchSetting(darkModeKey);
  if (isSuccess(result)) {
    display.darkMode = result.value === "true";
  }
}
