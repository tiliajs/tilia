import { localRepo } from "src/domain/repo/local";
import { makeApp } from "./domain/feature/app";

export const app_ = makeApp(localRepo);

const auth = app_.value.auth;

if (auth.t === "NotAuthenticated") {
  auth.login({ id: "main", name: "Main" });
}
