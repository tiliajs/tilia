import type { TodosFilter } from "@feature/todos";
import { isSuccess, type RepoReady } from "@service/repo";
import { type Setter } from "tilia";
import { filterKey } from "../actions/_utils";

export function fetchFilter(repo: RepoReady) {
  return async function fetchFilterValue(set: Setter<TodosFilter>) {
    const result = await repo.fetchSetting(filterKey);
    if (isSuccess(result)) {
      set(result.value as TodosFilter);
    }
  };
}
