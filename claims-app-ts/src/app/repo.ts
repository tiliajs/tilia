import { Store, make, type Change, type Kv, type Remote, type TiliaQuery } from "@tilia/query";
import { fields, match, type Claim, type ClaimQuery } from "./claim";

export type Repo = {
  claims: TiliaQuery<Claim, ClaimQuery>;
  // What the store offers beside the query object: writes, sync state, and
  // what to do about a refused one.
  store: Store<Claim>;
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
  persist: Kv,
  refresh: number = 30_000,
  memory: number = 120_000,
  now: () => number = Date.now
): Repo {
  const [claims, store] = make({
    id: (claim) => claim.id,
    // A changed claim enters and leaves query lists in place: writes never
    // trigger a find.
    matches: match,
    sort: () => (claims) => [...claims].sort((a, b) => a.id.localeCompare(b.id)),
    expiry: { refresh, memory },
    now,
    // The server pushes: it subscribes when live, so this one is described
    // by its channels rather than by what it does when asked.
    store: Store.custom({
      remote,
      persist,
      merge,
      expiry: { local: 30 * 24 * 60 * 60 * 1000 },
    }),
  });
  return { claims, store };
}
