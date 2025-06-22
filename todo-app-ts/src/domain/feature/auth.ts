import type { User } from "@entity/user";
import { type Auth, type AuthBlank } from "@feature/auth";
import type { Repo } from "@service/repo";
import { signal, type Signal } from "tilia";

// We use the convention of naming signals with a trailing
// underscore.

export function makeAuth(): Signal<Auth> {
  // There is probably a better way to do this, but I don't see it.
  const auth_ = signal<Auth>({ t: "Blank" } as AuthBlank);
  const enter = (auth: Auth) => (auth_.value = auth);
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
