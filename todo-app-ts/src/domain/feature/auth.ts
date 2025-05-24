import type { User } from "@model/user";
import { signal, type Signal } from "tilia";
import { type Auth } from "../interface/auth";

// We use the convention of naming signals with a trailing
// underscore.

export function makeAuth(): Signal<Auth> {
  const [auth_, enter] = signal<Auth>({} as Auth);
  logout(enter);
  return auth_;
}

function login(enter: (a: Auth) => void, user: User): void {
  enter({
    t: "Authenticated",
    user,
    logout: () => logout(enter),
  });
}

function logout(enter: (a: Auth) => void): void {
  enter({
    t: "NotAuthenticated",
    login: (user: User) => login(enter, user),
  });
}
