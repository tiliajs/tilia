import type { Todos } from "src/domain/api/feature/todos";
import { type RepoReady } from "src/domain/api/service/repo";
import { computed, connect, observe } from "tilia";
import { newTodo } from "./actions/_utils";
import { clear } from "./actions/clear";
import { edit } from "./actions/edit";
import { remove } from "./actions/remove";
import { save } from "./actions/save";
import { setFilter } from "./actions/setFilter";
import { setTitle } from "./actions/setTitle";
import { toggle } from "./actions/toggle";
import { data } from "./computed/data";
import { list } from "./computed/list";
import { remaining } from "./computed/remaining";
import { fetchFilterOnReady } from "./observers/fetchFilter";

export function makeTodos(repo: RepoReady) {
  const todos: Todos = connect({
    // State
    filter: "all",
    selected: newTodo(),

    // Computed state
    data: computed(() => data(repo, todos)),
    list: computed(() => list(todos)),
    remaining: computed(() => remaining(todos)),

    // Actions
    clear: () => clear(todos),
    edit: (todo) => edit(todos, todo),
    remove: (id) => remove(repo, todos, id),
    save: async (todo) => save(repo, todos, todo),
    setFilter: (filter) => setFilter(repo, todos, filter),
    setTitle: (title) => setTitle(todos, title),
    toggle: (id) => toggle(repo, todos, id),
  });

  observe(() => fetchFilterOnReady(repo, todos));

  return todos;
}
