export type User = {
  id: string;
  name: string;
};

export type Authenticated = { t: "Authenticated"; user: User };

export type AuthState =
  | { t: "NotAuthenticated" }
  | { t: "Authenticating" }
  | Authenticated;

export type Auth = {
  // State
  auth: AuthState;

  // Operations
  login: (user: User) => void;
  logout: () => void;
};

export function isAuthenticated(state: AuthState): state is Authenticated {
  return state.t === "Authenticated";
}

export function authenticated(user: User): Authenticated {
  return { t: "Authenticated", user };
}

export function notAuthenticated(): { t: "NotAuthenticated" } {
  return { t: "NotAuthenticated" };
}

export function authenticating(): { t: "Authenticating" } {
  return { t: "Authenticating" };
}
