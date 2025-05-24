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
import { type RepoReady } from "@interface/repo";
import type { Todos } from "@interface/todos";
import { computed, connect, observe, signal } from "tilia";
import { clear } from "./actions/clear";
import type { Todo } from "@model/todo";

/** Bind todos to the auth service. This is the todos adapter = implementation
 * of the todos port
 *
 */
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
