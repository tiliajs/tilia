import { isAuthenticated, type Auth } from "../interface/auth";
import { fail, success, type Repo, type Result } from "../interface/repo";
import { type Context } from "../model/context";
import type { Todo } from "../model/todo";

type IndexedDBRepo = Repo & {
  db?: IDBDatabase;
};

export function localStore({ connect, observe }: Context, auth: Auth): Repo {
  // auth not used with local storage
  const repo: IndexedDBRepo = connect({
    state: { t: "NotAuthenticated" },
    // Operations
    saveTodo: (todo) => saveTodo(repo, todo),
    removeTodo: (id) => removeTodo(repo, id),
    fetchTodos: () => fetchTodos(repo),
    saveSetting: (key, value) => saveSetting(repo, key, value),
    fetchSetting: (key) => fetchSetting(repo, key),
  });

  observe(() => {
    if (isAuthenticated(auth.auth)) {
      if (!repo.db) {
        repo.state = { t: "Opening" };
        getDb(repo, auth.auth.user.id);
      }
    } else {
      if (repo.db) {
        repo.db.close();
        repo.db = undefined;
      }
      repo.state = { t: "NotAuthenticated" };
    }
  });
  return repo;
}

const TODOS_TABLE = "todos";
const SETTINGS_TABLE = "settings";

async function saveTodo(
  repo: IndexedDBRepo,
  todo: Todo
): Promise<Result<Todo>> {
  if (!repo.db) {
    return fail("Database not open");
  }
  const transaction = repo.db.transaction(TODOS_TABLE, "readwrite");
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
  repo: IndexedDBRepo,
  id: string
): Promise<Result<string>> {
  if (!repo.db) {
    return fail("Database not open");
  }
  const transaction = repo.db.transaction(TODOS_TABLE, "readwrite");
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

async function fetchTodos(repo: IndexedDBRepo): Promise<Result<Todo[]>> {
  const { db } = repo;
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
  repo: IndexedDBRepo,
  key: string,
  value: string
): Promise<Result<string>> {
  if (!repo.db) {
    return fail("Database not open");
  }
  const transaction = repo.db.transaction(SETTINGS_TABLE, "readwrite");
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
  repo: IndexedDBRepo,
  key: string
): Promise<Result<string>> {
  if (!repo.db) {
    return fail("Database not open");
  }
  const transaction = repo.db.transaction(SETTINGS_TABLE, "readonly");
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

function getDb(repo: IndexedDBRepo, userId: string) {
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
    repo.state = {
      t: "Error",
      message: `Database error: ${request.error?.message || "Unknown error"}`,
    };
  };

  request.onsuccess = function (event) {
    const db = (event.target as IDBRequest).result;
    repo.db = db;
    repo.state = { t: "Ready" };

    db.onerror = function () {
      console.error("Database error:", db.error);
      repo.state = {
        t: "Error",
        message: `Database error: ${db.error?.message || "Unknown error"}`,
      };
    };
  };
}
