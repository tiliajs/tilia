import type { ClaimQuery } from "../../claim";
import type { Repo } from "../../repo";
import type { User } from "../../user";
import type { ClaimsFeature, Tab } from "./type";

export const query = (tab: Tab, user: User): ClaimQuery => {
  switch (tab) {
    case "mine":
      return { adjuster: user.name };
    case "all":
      return {};
    default:
      return { status: tab };
  }
};

export const list = (repo: Repo, user: User) => (self: ClaimsFeature) =>
  repo.claims.array(query(self.tab, user));
