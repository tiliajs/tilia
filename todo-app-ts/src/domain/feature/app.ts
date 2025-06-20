import type { App } from "@feature/app";
import { isAuthenticated, type AuthNotAuthenticated } from "@feature/auth";
import { observe, signal } from "tilia";
import { makeAuth } from "./auth";
import { makeDisplay } from "./display";
import { makeTodos } from "./todos/todos";

export function makeApp() {
  // We use the auth signal to manage state that should not be visible in the
  // app and to sync between different parts of the app (app, repo, todos).
  const auth_ = makeAuth();
  // Dummy display until authenticated.
  const display = makeDisplay({ value: { t: "NotAuthenticated" } });

  const [app_, set] = signal<App>({
    t: "Blank",
    display,
    auth: auth_.value as AuthNotAuthenticated,
  });

  observe(() => {
    const app = app_.value;
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
  });
  return { app_, auth_ };
}
