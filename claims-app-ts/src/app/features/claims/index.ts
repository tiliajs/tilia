import { carve, computed, observe } from "tilia";
import type { Repo } from "../../repo";
import type { User } from "../../user";
import * as actions from "./actions";
import { list, query } from "./computed";
import type { ClaimsFeature } from "./type";

export const claimsBranch = (repo: Repo, user: User): ClaimsFeature => {
  let active = false;
  const branch = carve<ClaimsFeature>(({ derived }) => ({
    tab: "mine",
    list: derived((self) => {
      active = true;
      return list(repo, user)(self);
    }),
    pending: computed(() => repo.claims.status.pending),
    rejected: computed(() => repo.claims.status.rejected),
    editing: null,
    resolution: null,
    filter: derived(actions.filter),
    create: derived(actions.create),
    take: actions.take(repo, user),
    close: actions.close(repo),
    edit: derived(actions.edit),
    commit: derived(actions.commit(repo)),
    cancel: derived(actions.cancel),
    remove: actions.remove(repo),
    dismiss: actions.dismiss(repo),
    resolve: derived(actions.resolve),
    saveResolution: derived(actions.saveResolution(repo)),
    discardResolution: derived(actions.discardResolution(repo)),
    tick: () => {
      if (!active) {
        repo.claims.tick();
        return;
      }
      // Keep the query visible to the engine while ticking through this
      // feature's derived list boundary.
      const close = observe(() => {
        const result = repo.claims.array(query(branch.tab, user));
        if (typeof result === "object" && result.state === "loaded") result.data.length;
      });
      repo.claims.tick();
      close();
    },
  }));
  return branch;
};
