import type { Loadable, Rejection } from "@tilia/query";
import type { Claim, Status } from "../../claim";

export type Tab = Status | "mine" | "all";

export type ClaimsFeature = {
  // Read
  tab: Tab;
  list: Loadable<Claim[]>;
  pending: number;
  rejected: readonly Rejection<Claim>[];

  // Local state: the draft being edited (a plain clone, committed on save).
  editing: Claim | null;

  // Actions
  filter(tab: Tab): void;
  create(): void;
  take(claim: Claim): void;
  close(claim: Claim): void;
  edit(claim: Claim): void;
  commit(): void;
  cancel(): void;
  remove(claim: Claim): void;
  dismiss(): void;
};
