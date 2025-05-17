import { connect, observe } from "../tilia";
import { isAuthenticated, type Auth } from "../types/auth";
import type { Filters } from "../types/display";
import { fail, success, type Result, type Store } from "../types/store";
import type { Todo } from "../types/todos";

type IndexedStore = Store & {
  db?: IDBDatabase;
};

export function makeStore(auth: Auth): Store {
  // auth not used with local storage
  const store: IndexedStore = connect({
    state: { t: "NotAuthenticated" },
    // Operations
    saveTodo: (todo: Todo) => saveTodo(auth, store, todo),
    removeTodo: (id: string) => removeTodo(auth, store, id),
    fetchTodos: () => fetchTodos(store),
    saveFilters: (filters: Filters) => saveFilters(store, filters),
    fetchFilters: () => fetchFilters(store),
  });

  observe(() => {
    if (isAuthenticated(auth.auth)) {
      if (!store.db) {
        store.state = { t: "Opening" };
        getDb(store, auth.auth.user.id);
      }
    } else {
      if (store.db) {
        store.db.close();
        store.db = undefined;
      }
      store.state = { t: "NotAuthenticated" };
    }
  });
  return store;
}

const TODOS_TABLE = "todos";
const FILTERS_TABLE = "filters";

async function saveTodo(
  { auth }: Auth,
  store: IndexedStore,
  aTodo: Todo
): Promise<Result<Todo>> {
  if (!store.db) {
    return fail("Database not open");
  }
  if (!isAuthenticated(auth)) {
    return fail("Not authenticated");
  }
  const todo = { ...aTodo, userId: auth.user.id };
  const transaction = store.db.transaction(TODOS_TABLE, "readwrite");
  const objectStore = transaction.objectStore(TODOS_TABLE);
  const request = objectStore.put(todo);
  return new Promise((resolve) => {
    request.onsuccess = function () {
      resolve(success(todo));
    };
    request.onerror = function () {
      resolve(fail("Todo save failed"));
    };
  });
}

async function removeTodo(
  { auth }: Auth,
  store: IndexedStore,
  id: string
): Promise<Result<string>> {
  if (!store.db) {
    return fail("Database not open");
  }
  if (!isAuthenticated(auth)) {
    return fail("Not authenticated");
  }
  const transaction = store.db.transaction(TODOS_TABLE, "readwrite");
  const objectStore = transaction.objectStore(TODOS_TABLE);
  const request = objectStore.delete(id);
  return new Promise((resolve) => {
    request.onsuccess = function () {
      resolve(success(id)); // return the id of the deleted todo
    };
    request.onerror = function () {
      resolve(fail("Todo delete failed"));
    };
  });
}

async function fetchTodos(store: IndexedStore): Promise<Result<Todo[]>> {
  const { db } = store;
  if (!db) {
    return fail("Database not open");
  }
  const transaction = db.transaction(TODOS_TABLE, "readonly");
  const objectStore = transaction.objectStore(TODOS_TABLE);
  const request = objectStore.getAll();
  return new Promise((resolve) => {
    request.onsuccess = function () {
      resolve(success(request.result as Todo[]));
    };
    request.onerror = function () {
      resolve(fail("Todo fetch failed"));
    };
  });
}

async function saveFilters(
  store: IndexedStore,
  allFilters: Filters
): Promise<Result<Filters>> {
  if (!store.db) {
    return fail("Database not open");
  }
  const transaction = store.db.transaction(FILTERS_TABLE, "readwrite");
  const objectStore = transaction.objectStore(FILTERS_TABLE);
  // We use a fixed key for filters (we only have one set).
  const filters = { id: "current", ...allFilters };
  const request = objectStore.put(filters);
  return new Promise((resolve) => {
    request.onsuccess = function () {
      resolve(success(filters));
    };
    request.onerror = function () {
      resolve(fail("Filters save failed"));
    };
  });
}

async function fetchFilters(store: IndexedStore): Promise<Result<Filters>> {
  if (!store.db) {
    return fail("Database not open");
  }
  const transaction = store.db.transaction(FILTERS_TABLE, "readonly");
  const objectStore = transaction.objectStore(FILTERS_TABLE);
  const request = objectStore.get("current");
  return new Promise((resolve) => {
    request.onsuccess = function () {
      if (request.result) {
        // Strip the ID from the result to return just the filters
        const { id, ...filters } = request.result;
        resolve(success(filters as Filters));
      } else {
        // Return default filters if none found
        resolve(success({ todos: "all" }));
      }
    };
    request.onerror = function () {
      resolve(fail("Filters fetch failed"));
    };
  });
}

//// Utility functions

function getDb(store: IndexedStore, userId: string) {
  const dbName = `todoapp_${userId}`;
  const request = indexedDB.open(dbName, 1);

  request.onupgradeneeded = function (event: IDBVersionChangeEvent) {
    const db = (event.target as IDBRequest).result;

    if (!db.objectStoreNames.contains(TODOS_TABLE)) {
      db.createObjectStore(TODOS_TABLE, { keyPath: "id" });
    }

    if (!db.objectStoreNames.contains(FILTERS_TABLE)) {
      db.createObjectStore(FILTERS_TABLE, { keyPath: "id" });
    }
  };

  request.onerror = function () {
    console.error("Database error:", request.error);
    store.state = {
      t: "Error",
      message: `Database error: ${request.error?.message || "Unknown error"}`,
    };
  };

  request.onsuccess = function (event) {
    const db = (event.target as IDBRequest).result;
    store.db = db;
    store.state = { t: "Ready" };

    db.onerror = function () {
      console.error("Database error:", db.error);
      store.state = {
        t: "Error",
        message: `Database error: ${db.error?.message || "Unknown error"}`,
      };
    };
  };
}
