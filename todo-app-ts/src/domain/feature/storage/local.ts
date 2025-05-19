import { isAuthenticated, type Auth } from "../../interface/auth";
import { fail, success, type Result, type Store } from "../../interface/store";
import { type Context } from "../../model/context";
import type { Todo } from "../../model/todo";

type IndexedStore = Store & {
  db?: IDBDatabase;
};

export function localStore({ connect, observe }: Context, auth: Auth): Store {
  // auth not used with local storage
  const store: IndexedStore = connect({
    state: { t: "NotAuthenticated" },
    // Operations
    saveTodo: (todo) => saveTodo(store, todo),
    removeTodo: (id) => removeTodo(store, id),
    fetchTodos: () => fetchTodos(store),
    saveSetting: (key, value) => saveSetting(store, key, value),
    fetchSetting: (key) => fetchSetting(store, key),
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
const SETTINGS_TABLE = "settings";

async function saveTodo(
  store: IndexedStore,
  todo: Todo
): Promise<Result<Todo>> {
  if (!store.db) {
    return fail("Database not open");
  }
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
  store: IndexedStore,
  id: string
): Promise<Result<string>> {
  if (!store.db) {
    return fail("Database not open");
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

async function saveSetting(
  store: IndexedStore,
  key: string,
  value: string
): Promise<Result<string>> {
  if (!store.db) {
    return fail("Database not open");
  }
  const transaction = store.db.transaction(SETTINGS_TABLE, "readwrite");
  const objectStore = transaction.objectStore(SETTINGS_TABLE);
  // We use a fixed key for filters (we only have one set).
  const settings = { id: key, value };
  const request = objectStore.put(settings);
  return new Promise((resolve) => {
    request.onsuccess = function () {
      resolve(success(value));
    };
    request.onerror = function () {
      resolve(fail("Filters save failed"));
    };
  });
}

async function fetchSetting(
  store: IndexedStore,
  key: string
): Promise<Result<string>> {
  if (!store.db) {
    return fail("Database not open");
  }
  const transaction = store.db.transaction(SETTINGS_TABLE, "readonly");
  const objectStore = transaction.objectStore(SETTINGS_TABLE);
  const request = objectStore.get(key);
  return new Promise((resolve) => {
    request.onsuccess = function () {
      if (request.result) {
        resolve(success(request.result.value));
      } else {
        resolve(fail("Setting not found"));
      }
    };
    request.onerror = function () {
      resolve(fail("Setting fetch failed"));
    };
  });
}

// ======= PRIVATE ========================

function getDb(store: IndexedStore, userId: string) {
  const dbName = `todoapp_${userId}`;
  const request = indexedDB.open(dbName, 1);

  request.onupgradeneeded = function (event: IDBVersionChangeEvent) {
    const db = (event.target as IDBRequest).result;

    if (!db.objectStoreNames.contains(TODOS_TABLE)) {
      db.createObjectStore(TODOS_TABLE, { keyPath: "id" });
    }

    if (!db.objectStoreNames.contains(SETTINGS_TABLE)) {
      db.createObjectStore(SETTINGS_TABLE, { keyPath: "id" });
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
