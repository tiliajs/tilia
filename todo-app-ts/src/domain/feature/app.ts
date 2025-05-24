import type { App } from "@interface/app";
import {
  isAuthenticated,
  type Auth,
  type AuthNotAuthenticated,
} from "@interface/auth";
import type { Repo } from "@interface/repo";
import { update, type Signal } from "tilia";
import { makeAuth } from "./auth";
import { makeDisplay } from "./display";
import { makeTodos } from "./todos/todos";

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
    (app, set) => {
      const auth = auth_.value;
      const repo = repo_.value;
      if (!isAuthenticated(auth)) {
        if (app.t !== "NotAuthenticated") {
          set({ t: "NotAuthenticated", auth, display });
        }
        return;
      }

      switch (app.t) {
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
                display,
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
}
