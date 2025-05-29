import type { Auth } from "src/domain/api/feature/auth";
import { update, type Signal } from "tilia";
import type { Todo } from "../../domain/api/model/todo";
import { fail, success, type Repo } from "../../domain/api/service/repo";

export function memoryStore(
  auth_: Signal<Auth>,
  initialTodos: Todo[] = [],
  initialSettings = {
    ["todos.filter"]: "all",
    ["display.darkMode"]: "false",
  } as Record<string, string>
): Signal<Repo> {
  return update<Repo>({ t: "NotAuthenticated" }, (prev, set) => {
    if (prev.t !== "Ready" && auth_.value.t === "Authenticated") {
      const userId = auth_.value.user.id;
      set({
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
      });
    }
  });
}
