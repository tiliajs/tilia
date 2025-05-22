import { type App } from "@interface/app";
import { type Auth, type AuthNotAuthenticated } from "@interface/auth";
import type { Repo } from "@interface/repo";
import { type Tilia } from "tilia";
import { makeAuth } from "./auth";
import { makeDisplay } from "./display";
import { makeTodos } from "./todos/todos";

function step<T>(ctx: Tilia, init: T, callback: (prec: T) => T): T {
  let prec = init;
  return ctx.computed<T>(() => {
    prec = callback(prec);
    return prec;
  });
}

export function makeApp(
  ctx: Tilia,
  makeRepo: (ctx: Tilia, auth: Auth) => Repo
) {
  const app = ctx.connect<App>({
    t: "NotAuthenticated",
    auth: makeAuth(ctx),
  });

  return ctx.connect({
    app: step(ctx, app, (app) => {
      switch (app.t) {
        case "NotAuthenticated": {
          if (app.auth.t === "Authenticated" /* Authentication event */) {
            // ========== enter Loading state
            return { t: "Loading", auth: app.auth, repo: makeRepo(ctx, auth) };
          }
          break;
        }

        case "Loading": // continue
        case "Ready": {
          switch (app.repo.t) {
            case "Ready": {
              if (app.t === "Loading") {
                // ========== enter Ready state
                enter({
                  t: "Ready",
                  auth: app.auth,
                  repo: app.repo,
                  display: makeDisplay(ctx, app.repo),
                  todos: makeTodos(ctx, app.auth, app.repo),
                });
              }
              break;
            }
            case "Error": {
              // ========== enter Error state
              enter({
                t: "Error",
                auth,
                error: app.repo.error,
              });
              break;
            }
            case "Closed": {
              // ========== enter NotAuthenticated state
              enter({
                t: "NotAuthenticated",
                auth: makeAuth(ctx) as AuthNotAuthenticated,
              });
              break;
            }
          }
          break;
        }
      }
    }),
  });
}

// ======= PRIVATE ========================
