import { carve, computed } from "tilia";
import type { Repo } from "../../repo";
import type { User } from "../../user";
import * as actions from "./actions";
import { list } from "./computed";
import type { ClaimsFeature } from "./type";

export const claimsBranch = (repo: Repo, user: User): ClaimsFeature =>
  carve<ClaimsFeature>(({ derived }) => ({
    tab: "mine",
    list: derived(list(repo, user)),
    pending: computed(() => repo.claims.status.pending),
    rejected: computed(() => repo.claims.status.rejected),
    editing: null,
    filter: derived(actions.filter),
    create: derived(actions.create),
    take: actions.take(repo, user),
    close: actions.close(repo),
    edit: derived(actions.edit),
    commit: derived(actions.commit(repo)),
    cancel: derived(actions.cancel),
    remove: actions.remove(repo),
    dismiss: actions.dismiss(repo),
  }));
