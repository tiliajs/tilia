import type { Todo } from "@entity/todo";
import type { Todos } from "@feature/todos";
import { type RepoReady } from "@service/repo";
import { carve, source } from "tilia";
import { newTodo } from "./actions/_utils";
import { clear } from "./actions/clear";
import { edit } from "./actions/edit";
import { remove } from "./actions/remove";
import { save } from "./actions/save";
import { setFilter } from "./actions/setFilter";
import { setTitle } from "./actions/setTitle";
import { toggle } from "./actions/toggle";
import { list } from "./derived/list";
import { remaining } from "./derived/remaining";
import { fetchFilter } from "./source/fetchFilter";

export function makeTodos(repo: RepoReady, data: Todo[]) {
  return carve<Todos>(({ derived }) => ({
    // State
    filter: source(fetchFilter(repo), "all"),
    selected: newTodo(),

    // Computed state
    list: derived(list),
    remaining: derived(remaining),

    // Actions
    clear: derived(clear),
    edit: derived(edit),
    remove: derived(remove),
    save: derived(save),
    setFilter: derived(setFilter),
    setTitle: derived(setTitle),
    toggle: derived(toggle),

    // Private state
    repo,
    data,
  }));
}
