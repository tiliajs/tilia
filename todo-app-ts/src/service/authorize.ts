import { isBlank, type Auth } from "@feature/auth";
import { supabase, supabaseRepo } from "src/service/repo/supabase";
import type { Signal } from "tilia";

export async function authorize(auth_: Signal<Auth>) {
  const auth = auth_.value;
  if (isBlank(auth)) {
    const {
      data: { user },
      error,
    } = await supabase.auth.getUser();

    if (error) {
      console.error(error);
      return;
    }
    console.log("User", user);

    // Auth might have changed, get latest value.
    const auth = auth_.value;
    if (auth.t !== "Authenticated") {
      if (user) {
        auth.login(supabaseRepo(auth_), {
          id: user.id,
          name: user.email?.split("@")[0] || "Supa User",
        });
      } else if (isBlank(auth)) {
        auth.logout();
      }
    }
  }
}
