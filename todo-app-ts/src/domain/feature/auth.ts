import {
  authenticated,
  notAuthenticated,
  type Auth,
  type User,
} from "../interface/auth";
import { type Context } from "../model/context";

/** Trivial auth adapter.
 *
 */
export function makeAuth({ connect }: Context) {
  const auth: Auth = connect({
    auth: notAuthenticated(),
    login: (user: User) => (auth.auth = authenticated(user)),
    logout: () => (auth.auth = notAuthenticated()),
  });
  return auth;
}

// ======= PRIVATE ========================
