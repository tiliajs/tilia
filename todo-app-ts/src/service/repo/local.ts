import { type Auth } from "@feature/auth";
import type { Todo } from "@model/todo";
import { fail, success, type Repo, type Result } from "@service/repo";
import { observe, signal, type Setter, type Signal } from "tilia";

type IndexedDBRepo = Repo & {
  db?: IDBDatabase;
};

export function localRepo(auth_: Signal<Auth>): Signal<Repo> {
  const [repo_, set] = signal<IndexedDBRepo>({ t: "NotAuthenticated" });
  observe(() => {
    const repo = repo_.value;
    const auth = auth_.value;
    if (auth.t !== "Authenticated") {
      if (repo.t === "Ready") {
        repo.db?.close();
        set({ t: "Closed" });
      }
      return;
    }

    switch (repo.t) {
      case "Closed": // Continue (authenticated and closed)
      case "NotAuthenticated": {
        set({ t: "Opening" });
        getDb(set, auth.user.id);
        break;
      }
      case "Opened": {
        set({
          t: "Ready",
          db: repo.db,
          // Operations
          saveTodo: (todo) => saveTodo(repo, todo, auth.user.id),
          removeTodo: (id) => removeTodo(repo, id),
          fetchTodos: () => fetchTodos(repo),
          saveSetting: (key, value) => saveSetting(repo, key, value),
          fetchSetting: (key) => fetchSetting(repo, key),
        });
        break;
      }
    }
  });
  return repo_;
}

const TODOS_TABLE = "todos";
const SETTINGS_TABLE = "settings";

async function saveTodo(
  repo: IndexedDBRepo,
  atodo: Todo,
  userId: string
): Promise<Result<Todo>> {
  if (!repo.db) {
    return fail("Database not open");
  }
  const todo: Todo = { ...atodo, userId };

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

function getDb(enter: Setter<IndexedDBRepo>, userId: string) {
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
    enter({
      t: "Error",
      error: `Database error: ${request.error?.message || "Unknown error"}`,
    });
  };

  request.onsuccess = function (event) {
    const db = (event.target as IDBRequest).result;
    enter({ t: "Opened", db });

    db.onerror = function () {
      console.error("Database error:", db.error);
      enter({
        t: "Error",
        error: `Database error: ${db.error?.message || "Unknown error"}`,
      });
    };
  };
}
