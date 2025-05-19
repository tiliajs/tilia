import { makeAuth } from "./feature/auth";
import { makeDisplay } from "./feature/display";
import { makeTodos } from "./feature/todos/todos";
import { makeContext } from "./model/context";
import { localStore } from "./repo/local";

const ctx = makeContext();
const auth = makeAuth(ctx);
const store = localStore(ctx, auth);
const display = makeDisplay(ctx, store);
const todos = makeTodos(ctx, auth, store);

auth.login({ id: "main", name: "Main" });

export const app = ctx.connect({
  auth,
  display,
  store,
  todos,
});
