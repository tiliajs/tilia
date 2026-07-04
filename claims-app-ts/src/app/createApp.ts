import type { Remote, Store } from "@tilia/query";
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
  local: Store<Claim, ClaimQuery>;
  stale: number;
  gc: number;
};

export function createApp({ user, remote, local, stale, gc }: Deps): App {
  const repo = makeRepo(remote, local, stale, gc);
  return {
    user,
    claims: claimsBranch(repo, user),
    tick: () => repo.claims.tick(),
    canopy: () => repo.claims.canopy(),
    dispose: () => repo.claims.dispose(),
  };
}
