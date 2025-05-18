import { v4 as uuid } from "uuid";
import { isAuthenticated, type Auth } from "../ports/auth";
import { fail, isReady, isSuccess, type Store } from "../ports/store";
import type { Todos, TodosFilter } from "../ports/todos";
import type { Context } from "../tilia";
import {
  blank,
  isLoaded,
  loaded,
  loading,
  type Loadable,
} from "../types/loadable";
import type { Todo } from "../types/todo";

const filterKey = "todos.filter";

/** Bind todos to the auth service. This is the todos adapter = implementation
 * of the todos port
 *
 */
export function makeTodos(
  { connect, computed, observe }: Context,
  auth: Auth,
  store: Store
) {
  async function saveTodo(atodo: Todo) {
    if (!isAuthenticated(auth.auth)) {
      return fail("Not authenticated");
    }
    const todo = { ...atodo, userId: auth.auth.user.id };
    return store.saveTodo(todo);
  }

  const todos: Todos = connect({
    // State
    filter: "all",
    data: computed(() => data(todos, auth, store)),
    list: computed(() => list(todos)),
    selected: newTodo(),
    remaining: computed(() => remaining(todos)),

    // Operations
    save: async (atodo: Todo) => {
      if (isLoaded(todos.data)) {
        const isNew = atodo.id === "";
        const todo = { ...atodo };
        if (isNew) {
          todo.createdAt = new Date().toISOString();
          todo.id = uuid();
        }
        todos.selected = newTodo();
        const result = await saveTodo(todo);
        if (isSuccess(result)) {
          const todo = result.value;
          if (isNew) {
            todos.data.value.push(todo);
          } else {
            // mutate in place
            Object.assign(todo, result.value);
          }
          return todo;
        } else {
          throw new Error(`Cannot save (${result.message})`);
        }
      } else {
        throw new Error("Cannot save (data not yet loaded)");
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
    setFilter: (filter: TodosFilter) => {
      todos.filter = filter;
      store.saveSetting(filterKey, filter);
    },
    toggle: (id: string) => {
      if (isLoaded(todos.data)) {
        const todo = todos.data.value.find((t) => t.id === id);
        if (todo) {
          todo.completed = !todo.completed;
          saveTodo(todo);
        }
      }
    },
  });

  observe(() => {
    if (isReady(store)) {
      fetchFilter(todos, store);
    }
  });

  return todos;
}

async function fetchFilter(todos: Todos, store: Store) {
  const result = await store.fetchSetting(filterKey);
  if (isSuccess(result)) {
    todos.filter = result.value as TodosFilter;
  }
}

function data(todos: Todos, { auth }: Auth, store: Store): Loadable<Todo[]> {
  if (isAuthenticated(auth) && isReady(store)) {
    loadTodos(todos, store.fetchTodos, auth.user.id);
    return loading();
  } else {
    return blank();
  }
}

function list(todos: Todos): Todo[] {
  const { data } = todos;
  if (isLoaded(data)) {
    const l = data.value
      .filter(listFilter(todos.filter))
      .sort((a, b) => (b.createdAt > a.createdAt ? 1 : -1));
    return l;
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

function listFilter(filter: TodosFilter): (todo: Todo) => boolean {
  switch (filter) {
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
    createdAt: "",
    userId: "", // userId is set on save.
    title: "",
    completed: false,
  };
}
