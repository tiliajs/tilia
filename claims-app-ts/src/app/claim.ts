export type Status = "new" | "assigned" | "inspected" | "closed";

export type Claim = {
  id: string;
  claimant: string;
  peril: string;
  city: string;
  status: Status;
  adjuster: string;
  estimate: number;
  notes: string;
  // Server version for optimistic concurrency: the server bumps it on every
  // accepted write and answers `conflict` when a stale version comes in.
  version: number;
};

export type ClaimField = keyof Omit<Claim, "id" | "version">;

export const fields: ClaimField[] = [
  "claimant",
  "peril",
  "city",
  "status",
  "adjuster",
  "estimate",
  "notes",
];

// Empty query = all claims. Both the local store and the simulated server
// interpret queries through `match`, as required by the adapter contract.
export type ClaimQuery = {
  status?: Status;
  adjuster?: string;
};

// The server refuses estimates above the adjuster authority limit.
export const limit = 50000;

export const statuses: Status[] = ["new", "assigned", "inspected", "closed"];

export function match(query: ClaimQuery, claim: Claim): boolean {
  return (
    (query.status === undefined || claim.status === query.status) &&
    (query.adjuster === undefined || claim.adjuster === query.adjuster)
  );
}

// Tilia proxies break structuredClone; claims are plain JSON data.
export const clone = <T>(value: T): T => JSON.parse(JSON.stringify(value));
