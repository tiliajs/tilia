import type {
  Auth,
  AuthAuthenticated,
  AuthNotAuthenticated,
} from "@interface/auth";
import type { Display } from "@interface/display";
import type { Todos } from "@interface/todos";

export type AppBlank = {
  t: "Blank";
  auth: AuthNotAuthenticated;
  display: Display;
};

export type AppNotAuthenticated = {
  t: "NotAuthenticated";
  auth: AuthNotAuthenticated;
  display: Display;
};

export type AppLoading = {
  t: "Loading";
  auth: AuthAuthenticated;
  display: Display;
};

export type AppError = {
  t: "Error";
  auth: Auth;
  display: Display;
  error: string;
};

export type AppReady = {
  t: "Ready";
  auth: AuthAuthenticated;
  display: Display;
  todos: Todos;
};

export type App =
  | AppBlank
  | AppNotAuthenticated
  | AppLoading
  | AppReady
  | AppError;

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
