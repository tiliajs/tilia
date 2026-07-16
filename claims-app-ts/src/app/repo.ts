import { make, type Change, type Local, type Remote, type TiliaQuery } from "@tilia/query";
import { fields, match, type Claim, type ClaimQuery } from "./claim";

export type Repo = {
  claims: TiliaQuery<Claim, ClaimQuery>;
};

const merge = (change: Change<Claim>, remote: Claim): boolean => {
  switch (change.TAG) {
    case "Clean":
      if (change._0.id !== remote.id) return false;
      Object.assign(change._0, remote);
      return true;
    case "Created":
      if (change._0.id !== remote.id || fields.some((field) => change._0[field] !== remote[field])) {
        return false;
      }
      change._0.version = remote.version;
      return true;
    case "Updated": {
      const base = change._0;
      const edited = change._1;
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
    case "Removed":
      if (change._0.id !== remote.id) return false;
      Object.assign(change._0, remote);
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
