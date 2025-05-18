import {
  authenticated,
  notAuthenticated,
  type Auth,
  type User,
} from "../ports/auth";
import { type Context } from "../tilia";

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

// ======= Utility functions ==================
