import type { Auth } from "@interface/auth";
import { update, type Signal } from "tilia";
import { fail, success, type Repo } from "../interface/repo";
import type { Todo } from "../model/todo";

export function memoryStore(
  initialTodos: Todo[] = [],
  initialSettings = {
    ["todos.filter"]: "all",
    ["display.darkMode"]: "false",
  } as Record<string, string>
): (auth: Signal<Auth>) => Signal<Repo> {
  return (auth_: Signal<Auth>) => {
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
  };
}
