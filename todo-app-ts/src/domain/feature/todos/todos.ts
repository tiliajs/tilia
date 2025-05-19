import { newTodo } from "@feature/todos/actions/_utils";
import { edit } from "@feature/todos/actions/edit";
import { remove } from "@feature/todos/actions/remove";
import { save } from "@feature/todos/actions/save";
import { setFilter } from "@feature/todos/actions/setFilter";
import { setTitle } from "@feature/todos/actions/setTitle";
import { toggle } from "@feature/todos/actions/toggle";
import { data } from "@feature/todos/computed/data";
import { list } from "@feature/todos/computed/list";
import { remaining } from "@feature/todos/computed/remaining";
import { fetchFilterOnReady } from "@feature/todos/observers/fetchFilter";
import { type Auth } from "@interface/auth";
import { type Store } from "@interface/store";
import type { Todos } from "@interface/todos";
import type { Context } from "@model/context";
import { clear } from "./actions/clear";

/** Bind todos to the auth service. This is the todos adapter = implementation
 * of the todos port
 *
 */
export function makeTodos(
  { connect, computed, observe }: Context,
  auth: Auth,
  store: Store
) {
  const todos: Todos = connect({
    // State
    filter: "all",
    selected: newTodo(),

    // Computed state
    data: computed(() => data(auth, store, todos)),
    list: computed(() => list(todos)),
    remaining: computed(() => remaining(todos)),

    // Actions
    clear: () => clear(todos),
    edit: (todo) => edit(todos, todo),
    remove: (id) => remove(store, todos, id),
    save: async (todo) => save(auth, store, todos, todo),
    setFilter: (filter) => setFilter(store, todos, filter),
    setTitle: (title) => setTitle(todos, title),
    toggle: (id) => toggle(auth, store, todos, id),
  });

  observe(() => fetchFilterOnReady(store, todos));

  return todos;
}
