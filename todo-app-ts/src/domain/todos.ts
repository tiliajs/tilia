import { v4 as uuid } from "uuid";
import { computed, connect } from "./tilia";
import { isAuthenticated, type Auth } from "./types/auth";
import type { Display, Filters } from "./types/display";
import {
  blank,
  isLoaded,
  loaded,
  loading,
  type Loadable,
} from "./types/loadable";
import { isReady, isSuccess, type Store } from "./types/store";
import type { Todo, Todos } from "./types/todos";

/** Bind todos to the auth service. This is the todos adapter = implementation
 * of the todos port
 *
 */
export function makeTodos(auth: Auth, display: Display, store: Store) {
  const todos: Todos = connect({
    // State
    data: computed(() => data(todos, auth, store)),
    list: computed(() => list(todos, display.filters)),
    selected: newTodo(),
    remaining: computed(() => remaining(todos)),

    // Operations
    save: async () => {
      if (isLoaded(todos.data)) {
        const result = await store.saveTodo(todos.selected);
        if (isSuccess(result)) {
          todos.data.value.push(result.value); //  = [...todos.data.value, result.value];
          todos.selected = newTodo();
        } // FIXME: handle error
      }
    },
    clear: () => {
      todos.selected = newTodo();
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

function list(todos: Todos, filters: Filters): Todo[] {
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

function listFilter(state: Filters["todos"]): (todo: Todo) => boolean {
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
    id: uuid(),
    userId: "", // userId is set on save.
    title: "",
    completed: false,
  };
}
