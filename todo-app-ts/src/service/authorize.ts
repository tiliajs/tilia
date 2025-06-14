import type { Signal } from "@model/signal";
import { isBlank, type Auth } from "src/domain/api/feature/auth";
import { supabase, supabaseRepo } from "src/service/repo/supabase";

export async function authorize(auth_: Signal<Auth>) {
  const auth = auth_.value;
  if (isBlank(auth)) {
    const {
      data: { user },
    } = await supabase.auth.getUser();

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
