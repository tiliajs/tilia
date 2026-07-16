import { clone, fields, type Claim } from "../../claim";
import type { Rejection } from "@tilia/query";
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
  repo.claims.remove(claim.id);
};

export const dismiss = (repo: Repo) => (rejection: Rejection<Claim>) => {
  repo.claims.dismiss(rejection);
};

export const resolve = (self: ClaimsFeature) => (rejection: Rejection<Claim>, theirs: Claim) => {
  if (rejection.TAG !== "UpdateConflict") return;
  const base = clone(rejection._0);
  const mine = clone(rejection._1);
  const current = clone(theirs);
  const draft = clone(theirs);
  const changed = fields.filter((field) => mine[field] !== base[field]);
  for (const field of changed) {
    if (current[field] === base[field]) Object.assign(draft, { [field]: mine[field] });
  }
  self.resolution = {
    rejection,
    base,
    mine,
    theirs: current,
    draft,
    fields: changed.filter(
      (field) => current[field] !== base[field] && mine[field] !== current[field]
    ),
  };
};

export const saveResolution = (repo: Repo) => (self: ClaimsFeature) => () => {
  if (!self.resolution) return;
  repo.claims.dismiss(self.resolution.rejection);
  repo.claims.upsert(clone(self.resolution.draft));
  self.resolution = null;
};

export const discardResolution = (repo: Repo) => (self: ClaimsFeature) => () => {
  if (!self.resolution) return;
  repo.claims.dismiss(self.resolution.rejection);
  self.resolution = null;
};
