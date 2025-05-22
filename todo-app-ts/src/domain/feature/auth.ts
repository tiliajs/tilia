import type { User } from "@model/user";
import type { Tilia } from "tilia";
import { type Auth } from "../interface/auth";

function move<T>(ctx: Tilia, callback: (enter: (v: T) => void) => T): T {
  let clbk = { enter: (_: T) => {} };
  const enter = (v: T) => clbk.enter(v);
  return ctx.computed<T>(() => callback(enter));
}

export function makeAuth(ctx: Tilia) {
  return move<Auth>(ctx, (enter) => ({
    t: "NotAuthenticated",
    login: (user) => login(enter, user),
  }));
}

// ======= PRIVATE ========================

function login(enter: (a: Auth) => void, user: User) {
  enter({
    t: "Authenticated",
    user,
    logout: () => logout(enter),
  });
}

function logout(enter: (a: Auth) => void) {
  enter({
    t: "NotAuthenticated",
    login: (user) => login(enter, user),
  });
}
