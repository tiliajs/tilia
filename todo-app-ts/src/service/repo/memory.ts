import type { Todo } from "@entity/todo";
import type { Auth } from "@feature/auth";
import { fail, success, type Repo, type RepoReady } from "@service/repo";
import { observe, signal, type Signal } from "tilia";

export function memoryStore(
  auth_: Signal<Auth>,
  initialTodos: Todo[] = [],
  initialSettings = {
    ["todos.filter"]: "all",
    ["display.darkMode"]: "false",
  } as Record<string, string>
): Signal<Repo> {
  const repo_ = signal<Repo>({ t: "NotAuthenticated" });
  const set = (repo: Repo) => (repo_.value = repo);
  observe(() => {
    const repo = repo_.value;
    const auth = auth_.value;
    if (repo.t !== "Ready" && auth.t === "Authenticated") {
      const userId = auth.user.id;
      set(readyMemoryStore(userId, initialTodos, initialSettings));
    }
  });
  return repo_;
}

export function readyMemoryStore(
  userId: string,
  initialTodos: Todo[] = [],
  initialSettings = {
    ["todos.filter"]: "all",
    ["display.darkMode"]: "false",
  } as Record<string, string>
): RepoReady {
  return {
    t: "Ready",
    // Operations
    saveTodo: async (todo: Todo) => success({ ...todo, userId }),
    removeTodo: async (id: string) => success(id),
    fetchTodos: async () => success(initialTodos),
    saveSetting: async (_key, value) => success(value),
    fetchSetting: async (key) => {
      const f = initialSettings[key];
      if (f) {
        return success(f);
      }
      return fail("No settings");
    },
  };
}
