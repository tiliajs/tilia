import type { Tilia } from "tilia";
import {
  authenticated,
  notAuthenticated,
  type Auth,
  type User,
} from "../interface/auth";

/** Trivial auth adapter.
 *
 */
export function makeAuth({ connect }: Tilia) {
  const auth: Auth = connect({
    auth: notAuthenticated(),
    login: (user: User) => (auth.auth = authenticated(user)),
    logout: () => (auth.auth = notAuthenticated()),
  });
  return auth;
}

// ======= PRIVATE ========================
