import type { Kv, Remote } from "@tilia/query";
import type { Claim, ClaimQuery } from "./claim";
import { claimsBranch } from "./features/claims";
import type { ClaimsFeature } from "./features/claims/type";
import { makeRepo } from "./repo";
import type { User } from "./user";

export type App = {
  user: User;
  claims: ClaimsFeature;
  tick(): void;
  canopy(): { live: string[]; idle: string[] };
  dispose(): void;
};

export type Deps = {
  user: User;
  remote: Remote<Claim, ClaimQuery>;
  persist: Kv;
  refresh: number;
  memory: number;
  now?: () => number;
};

export function createApp({ user, remote, persist, refresh, memory, now }: Deps): App {
  const repo = makeRepo(remote, persist, refresh, memory, now);
  const claims = claimsBranch(repo, user);
  return {
    user,
    claims,
    tick: () => claims.tick(),
    canopy: () => repo.claims._canopy(),
    dispose: () => repo.claims.dispose(),
  };
}
