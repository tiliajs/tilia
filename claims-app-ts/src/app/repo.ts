import { make, type Query, type Remote, type Store } from "@tilia/query";
import type { Claim, ClaimQuery } from "./claim";

export type Repo = {
  claims: Query<Claim, ClaimQuery>;
};

export function makeRepo(remote: Remote<Claim, ClaimQuery>, local: Store<Claim, ClaimQuery>): Repo {
  return {
    claims: make({
      id: (claim) => claim.id,
      remote,
      local,
      stale: 15,
      gc: 120,
      // A status change moves a claim between lists, so any change touches
      // every claim query. Invalidated queries refetch from the local store,
      // which is instant.
      invalidates: () => true,
    }),
  };
}
