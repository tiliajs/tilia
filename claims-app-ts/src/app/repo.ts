import { make, type Change, type Local, type Remote, type TiliaQuery } from "@tilia/query";
import { fields, match, type Claim, type ClaimQuery } from "./claim";

export type Repo = {
  claims: TiliaQuery<Claim, ClaimQuery>;
};

const merge = (change: Change<Claim>, remote: Claim): boolean => {
  switch (change.change) {
    case "clean":
      if (change.value.id !== remote.id) return false;
      Object.assign(change.value, remote);
      return true;
    case "created":
      if (
        change.edited.id !== remote.id ||
        fields.some((field) => change.edited[field] !== remote[field])
      ) {
        return false;
      }
      change.edited.version = remote.version;
      return true;
    case "updated": {
      const { base, edited } = change;
      if (base.id !== edited.id || edited.id !== remote.id) return false;
      const conflict = fields.some(
        (field) =>
          edited[field] !== base[field] && remote[field] !== base[field] && edited[field] !== remote[field]
      );
      if (conflict) return false;
      for (const field of fields) {
        if (edited[field] === base[field]) Object.assign(edited, { [field]: remote[field] });
      }
      edited.version = remote.version;
      return true;
    }
    case "removed":
      if (change.base.id !== remote.id) return false;
      Object.assign(change.base, remote);
      return true;
  }
};

export function makeRepo(
  remote: Remote<Claim, ClaimQuery>,
  local: Local<Claim, ClaimQuery>,
  refresh: number = 30_000,
  memory: number = 120_000,
  now: () => number = Date.now
): Repo {
  return {
    claims: make({
      id: (claim) => claim.id,
      remote,
      local,
      expiry: { refresh, memory, local: 30 * 24 * 60 * 60 * 1000 },
      now,
      // A changed claim enters and leaves query lists in place: writes never
      // trigger a fetch.
      matches: match,
      sort: () => (claims) => [...claims].sort((a, b) => a.id.localeCompare(b.id)),
      merge,
    }),
  };
}
