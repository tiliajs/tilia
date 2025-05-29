import type { App } from "src/domain/api/feature/app";
import {
  isAuthenticated,
  type AuthNotAuthenticated,
} from "src/domain/api/feature/auth";
import { update } from "tilia";
import { makeAuth } from "./auth";
import { makeDisplay } from "./display";
import { makeTodos } from "./todos/todos";

export function makeApp() {
  // Create the auth signal.
  // A signal is a varying value: basically `{ value }` that is observable.
  const auth_ = makeAuth();
  // Dummy display until authenticated.
  const display = makeDisplay({ value: { t: "NotAuthenticated" } });

  const app_ = update<App>(
    {
      t: "Blank",
      auth: auth_.value as AuthNotAuthenticated,
      display,
    },
    (app, set) => {
      const auth = auth_.value;
      if (auth.t === "Blank") {
        // Wait to avoid flicker.
        return;
      }

      if (!isAuthenticated(auth)) {
        if (app.t !== "NotAuthenticated") {
          set({ t: "NotAuthenticated", auth, display });
        }
        return;
      }

      const repo = auth.repo.value;

      switch (app.t) {
        case "Blank": // continue
        case "NotAuthenticated": {
          // ========== enter Loading state
          set({ t: "Loading", auth, display });
          break;
        }

        case "Loading": {
          switch (repo.t) {
            case "Ready": {
              // ========== enter Ready state
              set({
                t: "Ready",
                auth: auth,
                display: makeDisplay(auth.repo),
                todos: makeTodos(repo),
              });
              break;
            }
            case "Error": {
              // ========== enter Error state
              set({
                t: "Error",
                auth,
                display,
                error: repo.error,
              });
              break;
            }
            case "Closed": {
              // ========== enter NotAuthenticated state
              if (auth.t === "Authenticated") {
                auth.logout();
              } else {
                set({ t: "NotAuthenticated", auth, display });
                break;
              }
            }
          }
        }
      }
    }
  );
  return { app_, auth_ };
}
