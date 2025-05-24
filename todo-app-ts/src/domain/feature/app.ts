import type { App } from "@interface/app";
import {
  isAuthenticated,
  type Auth,
  type AuthNotAuthenticated,
} from "@interface/auth";
import type { Repo } from "@interface/repo";
import { observe, signal, type Signal } from "tilia";
import { makeAuth } from "./auth";
import { makeDisplay } from "./display";
import { makeTodos } from "./todos/todos";

function update<a>(init: a, fn: (p: a) => a): Signal<a> {
  const [s, set] = signal(init);
  observe(() => set(fn(s.value)));
  return s;
}

export function makeApp(makeRepo: (auth: Signal<Auth>) => Signal<Repo>) {
  // Create the auth signal.
  // A signal is a varying value: basically `{ value }` that is observable.
  const auth_ = makeAuth();
  const repo_ = makeRepo(auth_);
  const display = makeDisplay(repo_);

  return update<App>(
    {
      t: "NotAuthenticated",
      auth: auth_.value as AuthNotAuthenticated,
      display,
    },
    (app) => {
      const auth = auth_.value;
      const repo = repo_.value;
      if (!isAuthenticated(auth)) {
        if (app.t !== "NotAuthenticated") {
          return { t: "NotAuthenticated", auth, display };
        }
        return app;
      }

      switch (app.t) {
        case "NotAuthenticated": {
          // ========== enter Loading state
          return { t: "Loading", auth, display };
        }

        case "Loading": {
          switch (repo.t) {
            case "Ready": {
              // ========== enter Ready state
              return {
                t: "Ready",
                auth: auth,
                display,
                todos: makeTodos(repo),
              };
            }
            case "Error": {
              // ========== enter Error state
              return {
                t: "Error",
                auth,
                display,
                error: repo.error,
              };
              break;
            }
            case "Closed": {
              // ========== enter NotAuthenticated state
              if (auth.t === "Authenticated") {
                auth.logout();
              } else {
                return { t: "NotAuthenticated", auth, display };
              }
            }
          }
        }
      }
      return app;
    }
  );
}

// ======= PRIVATE ========================
