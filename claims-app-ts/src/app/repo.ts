import { make, type Collection, type Remote, type Store } from "@tilia/query";
import { match, type Claim, type ClaimQuery } from "./claim";

export type Repo = {
  claims: Collection<Claim, ClaimQuery>;
};

export function makeRepo(
  remote: Remote<Claim, ClaimQuery>,
  local: Store<Claim, ClaimQuery>,
  stale: number = 30,
  gc: number = 120
): Repo {
  return {
    claims: make({
      id: (claim) => claim.id,
      remote,
      local,
      stale,
      gc,
      // A changed claim enters and leaves query lists in place: writes never
      // trigger a fetch.
      matches: match,
      sort: (a, b) => a.id.localeCompare(b.id),
    }),
  };
}
