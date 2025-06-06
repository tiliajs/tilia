import { signal, type Signal } from "@model/signal";
import type { User } from "src/domain/api/model/user";
import type { Repo } from "src/domain/api/service/repo";
import { type Auth, type AuthBlank } from "../api/feature/auth";

// We use the convention of naming signals with a trailing
// underscore.

export function makeAuth(): Signal<Auth> {
  // There is probably a better way to do this, but I don't see it.
  const [auth_, enter] = signal<Auth>({ t: "Blank" } as AuthBlank);
  const auth = auth_.value as AuthBlank;
  auth.login = (repo: Signal<Repo>, user: User) => login(enter, repo, user);
  auth.logout = () => logout(enter);
  return auth_;
}

function login(enter: (a: Auth) => void, repo: Signal<Repo>, user: User): void {
  enter({
    t: "Authenticated",
    user,
    repo,
    logout: () => logout(enter),
  });
}

function logout(enter: (a: Auth) => void): void {
  enter({
    t: "NotAuthenticated",
    login: (repo: Signal<Repo>, user: User) => login(enter, repo, user),
  });
}
