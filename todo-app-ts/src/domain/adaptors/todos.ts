import { v4 as uuid } from "uuid";
import { isAuthenticated, type Auth } from "../ports/auth";
import type { Display, Settings } from "../ports/display";
import { isReady, isSuccess, type Store } from "../ports/store";
import type { Todos } from "../ports/todos";
import type { Context } from "../tilia";
import {
  blank,
  isLoaded,
  loaded,
  loading,
  type Loadable,
} from "../types/loadable";
import type { Todo } from "../types/todo";

/** Bind todos to the auth service. This is the todos adapter = implementation
 * of the todos port
 *
 */
export function makeTodos(
  { connect, computed }: Context,
  auth: Auth,
  display: Display,
  store: Store
) {
  const todos: Todos = connect({
    // State
    data: computed(() => data(todos, auth, store)),
    list: computed(() => list(todos, display.settings)),
    selected: newTodo(),
    remaining: computed(() => remaining(todos)),

    // Operations
    save: async (atodo: Todo) => {
      if (isLoaded(todos.data)) {
        const isNew = atodo.id === "";
        const todo = { ...atodo };
        if (isNew) {
          todo.id = uuid();
        }
        todos.selected = newTodo();
        const result = await store.saveTodo(todo);
        if (isSuccess(result)) {
          const todo = result.value;
          if (isNew) {
            todos.data.value.push(todo);
          } else {
            // mutate in place
            Object.assign(todo, result.value);
          }
        } // FIXME: handle error
      }
    },
    clear: () => {
      todos.selected = newTodo();
    },
    edit: (todo: Todo) => {
      if (todo === todos.selected) {
        todos.selected = newTodo();
      } else {
        todos.selected = todo;
      }
    },
    remove: async (id: string) => {
      if (isLoaded(todos.data)) {
        const result = await store.removeTodo(id);
        if (isSuccess(result)) {
          todos.data.value = todos.data.value.filter((t) => t.id !== id);
        }
        // FIXME: handle error
      }
    },
    setTitle: (title: string) => {
      todos.selected.title = title;
    },
    toggle: (id: string) => {
      if (isLoaded(todos.data)) {
        const todo = todos.data.value.find((t) => t.id === id);
        if (todo) {
          todo.completed = !todo.completed;
          store.saveTodo(todo);
        }
      }
    },
  });
  return todos;
}

function data(todos: Todos, { auth }: Auth, store: Store): Loadable<Todo[]> {
  if (isAuthenticated(auth) && isReady(store)) {
    loadTodos(todos, store.fetchTodos, auth.user.id);
    return loading();
  } else {
    return blank();
  }
}

function list(todos: Todos, filters: Settings): Todo[] {
  const { data } = todos;
  if (isLoaded(data)) {
    return data.value
      .filter(listFilter(filters.todos))
      .sort((a, b) => (a.title > b.title ? 1 : -1));
  }
  return [];
}

function remaining(todos: Todos): number {
  const { data } = todos;
  if (isLoaded(data)) {
    return data.value.filter((t) => !t.completed).length;
  }
  return 0;
}

// ======= Utility functions ==================
async function loadTodos(
  todos: Todos,
  fetchTodos: Store["fetchTodos"],
  userId: string
) {
  const data = await fetchTodos(userId);
  if (isSuccess(data)) {
    todos.data = loaded(data.value);
  } else {
    // Error already handled by the store
    todos.data = blank();
  }
}

function listFilter(state: Settings["todos"]): (todo: Todo) => boolean {
  switch (state) {
    case "active":
      return (f: Todo) => f.completed === false;
    case "completed":
      return (f: Todo) => f.completed === true;
    default:
      return (_: Todo) => true;
  }
}

function newTodo(): Todo {
  return {
    id: "",
    userId: "", // userId is set on save.
    title: "",
    completed: false,
  };
}
