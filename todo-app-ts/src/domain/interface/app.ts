import type {
  Auth,
  AuthAuthenticated,
  AuthNotAuthenticated,
} from "@interface/auth";
import type { Display } from "@interface/display";
import type { Repo, RepoReady } from "@interface/repo";
import type { Todos } from "@interface/todos";

export type AppNotAuthenticated = {
  t: "NotAuthenticated";
  auth: AuthNotAuthenticated;
};

export type AppLoading = {
  t: "Loading";
  auth: AuthAuthenticated;
  repo: Repo;
};

export type AppError = {
  t: "Error";
  auth: Auth;
  error: string;
};

export type AppReady = {
  t: "Ready";
  auth: AuthAuthenticated;
  repo: RepoReady;
  display: Display;
  todos: Todos;
};

export type App = AppNotAuthenticated | AppLoading | AppReady | AppError;

export function isAppNotAuthenticated(app: App): app is AppNotAuthenticated {
  return app.t === "NotAuthenticated";
}

export function isAppLoading(app: App): app is AppLoading {
  return app.t === "Loading";
}

export function isAppReady(app: App): app is AppReady {
  return app.t === "Ready";
}

export function isAppError(app: App): app is AppError {
  return app.t === "Error";
}
