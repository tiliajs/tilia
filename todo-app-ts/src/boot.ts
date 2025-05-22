import { localRepo } from "src/domain/repo/local";
import { make } from "tilia";
import { makeApp } from "./domain/feature/app";

const ctx = make();
export const app = makeApp(ctx, localRepo);

if (app.auth.t === "NotAuthenticated") {
  app.auth.login({ id: "main", name: "Main" });
}
