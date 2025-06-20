import type { Loadable } from "@entity/loadable";
import type { Todo } from "@entity/todo";
import type { Todos } from "@feature/todos";
import { type RepoReady } from "@service/repo";
import { computed, observe, store, tilia } from "tilia";
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
  const data_ = store<Loadable<Todo[]>>((set) => data(set, repo));
  const todos: Todos = tilia({
    // State
    t: computed(() => data_.value.t),
    filter: "all",
    selected: newTodo(),

    // Computed state
    list: computed(() => list(todos)),
    remaining: computed(() => remaining(todos)),

    // Actions
    clear: () => clear(todos),
    edit: (id) => edit(todos, id),
    remove: (id) => remove(repo, todos, id),
    save: async (todo) => save(repo, todos, todo),
    setFilter: (filter) => setFilter(repo, todos, filter),
    setTitle: (title) => setTitle(todos, title),
    toggle: (id) => toggle(repo, todos, id),

    // Private state
    data_,
  });

  observe(() => fetchFilterOnReady(repo, todos));

  return todos;
}
