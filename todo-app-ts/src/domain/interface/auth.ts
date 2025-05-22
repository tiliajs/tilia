import type { User } from "@model/user";

export type AuthNotAuthenticated = {
  // State
  t: "NotAuthenticated" | "Authenticating";

  // Operations
  login: (user: User) => void;
};

export type AuthAuthenticated = {
  // State
  t: "Authenticated";
  user: User;

  // Operations
  logout: () => void;
};

export type Auth = AuthNotAuthenticated | AuthAuthenticated;
