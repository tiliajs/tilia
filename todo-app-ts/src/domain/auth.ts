import { connect } from "./tilia";
import {
  authenticated,
  notAuthenticated,
  type Auth,
  type User,
} from "./types/auth";

/** Bind auth.
 *
 */
export function makeAuth(): Auth {
  const auth: Auth = connect({
    auth: notAuthenticated(),
    login: (user: User) => (auth.auth = authenticated(user)),
    logout: () => (auth.auth = notAuthenticated()),
  });
  return auth;
}

// ======= Utility functions ==================
