import { clone, type Claim } from "../../claim";
import type { Repo } from "../../repo";
import type { User } from "../../user";
import type { ClaimsFeature, Tab } from "./type";

export const filter = (self: ClaimsFeature) => (tab: Tab) => {
  self.tab = tab;
};

export const create = (self: ClaimsFeature) => () => {
  self.editing = {
    id: `CLM-${1000 + Math.floor(Math.random() * 9000)}`,
    claimant: "",
    peril: "",
    city: "",
    status: "new",
    adjuster: "",
    estimate: 0,
    notes: "",
    version: 0,
  };
};

export const take = (repo: Repo, user: User) => (claim: Claim) => {
  repo.claims.upsert({ ...clone(claim), status: "assigned", adjuster: user.name });
};

export const close = (repo: Repo) => (claim: Claim) => {
  repo.claims.upsert({ ...clone(claim), status: "closed" });
};

export const edit = (self: ClaimsFeature) => (claim: Claim) => {
  self.editing = clone(claim);
};

export const commit = (repo: Repo) => (self: ClaimsFeature) => () => {
  if (self.editing === null) return;
  repo.claims.upsert(clone(self.editing));
  self.editing = null;
};

export const cancel = (self: ClaimsFeature) => () => {
  self.editing = null;
};

export const remove = (repo: Repo) => (claim: Claim) => {
  repo.claims.remove(clone(claim));
};

export const dismiss = (repo: Repo) => () => {
  repo.claims.dismiss();
};
