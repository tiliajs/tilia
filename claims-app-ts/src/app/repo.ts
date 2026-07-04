import { make, type Query, type Remote, type Store } from "@tilia/query";
import { match, type Claim, type ClaimQuery } from "./claim";

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
      // A changed claim enters and leaves query lists in place: writes never
      // trigger a fetch.
      matches: match,
      sort: (a, b) => a.id.localeCompare(b.id),
    }),
  };
}
