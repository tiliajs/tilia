import { authorize } from "src/domain/repo/authorize";
import { makeApp } from "./domain/feature/app";

const { app_, auth_ } = makeApp();

export { app_, auth_ };

// Try to login with Supabase
authorize(auth_);
