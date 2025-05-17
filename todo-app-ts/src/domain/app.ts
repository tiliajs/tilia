import { makeAuth } from "./auth";
import { makeDisplay } from "./display";
import { makeStore } from "./storage/local";
import { connect } from "./tilia";
import { makeTodos } from "./todos";

const auth = makeAuth();
const store = makeStore(auth);
const display = makeDisplay(store);
const todos = makeTodos(auth, display, store);

auth.login({ id: "main", name: "Main" });

export const app = connect({
  auth,
  display,
  store,
  todos,
});
