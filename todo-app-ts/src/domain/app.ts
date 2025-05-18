import { makeAuth } from "./adaptors/auth";
import { makeDisplay } from "./adaptors/display";
import { makeStore } from "./adaptors/storage/local";
import { makeTodos } from "./adaptors/todos";
import { make } from "./tilia";

const ctx = make();
const auth = makeAuth(ctx);
const store = makeStore(ctx, auth);
const display = makeDisplay(ctx, store);
const todos = makeTodos(ctx, auth, display, store);

auth.login({ id: "main", name: "Main" });

export const app = ctx.connect({
  auth,
  display,
  store,
  todos,
});
