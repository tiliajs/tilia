import type { Signal } from "@model/signal";
import type { User } from "src/domain/api/model/user";
import type { Repo } from "src/domain/api/service/repo";

export type AuthBlank = {
  // State
  t: "Blank";

  // Operations
  login: (repo: Signal<Repo>, user: User) => void;
  logout: () => void;
};

export type AuthNotAuthenticated = {
  // State
  t: "Blank" | "NotAuthenticated" | "Authenticating";

  // Operations
  login: (repo: Signal<Repo>, user: User) => void;
};

export type AuthAuthenticated = {
  // State
  t: "Authenticated";
  repo: Signal<Repo>;
  user: User;

  // Operation
  logout: () => void;
};

export type Auth = AuthBlank | AuthNotAuthenticated | AuthAuthenticated;

export function isAuthenticated(auth: Auth): auth is AuthAuthenticated {
  return auth.t === "Authenticated";
}

export function isBlank(auth: Auth): auth is AuthBlank {
  return auth.t === "Blank";
}
