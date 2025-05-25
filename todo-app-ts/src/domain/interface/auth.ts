import type { Repo } from "@interface/repo";
import type { User } from "@model/user";
import type { Signal } from "tilia";

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
