import type { User } from "@entity/user";
import { type Auth } from "@feature/auth";
import type { Repo } from "@service/repo";
import { signal, store, type Setter, type Signal } from "tilia";

export function makeAuth() {
  const [s] = signal<Auth>(store((set) => blank(set)));
  return s;
}

function loggedIn(set: Setter<Auth>, repo: Signal<Repo>, user: User): Auth {
  return {
    t: "Authenticated",
    user,
    repo,
    logout: () => set(loggedOut(set)),
  };
}

function loggedOut(set: Setter<Auth>): Auth {
  return {
    t: "NotAuthenticated",
    login: (repo: Signal<Repo>, user: User) => set(loggedIn(set, repo, user)),
  };
}

function blank(set: Setter<Auth>): Auth {
  return {
    t: "Blank",
    login: (repo: Signal<Repo>, user: User) => set(loggedIn(set, repo, user)),
    logout: () => set(loggedOut(set)),
  };
}
