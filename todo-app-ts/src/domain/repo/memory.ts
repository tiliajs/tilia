import type { Auth } from "@interface/auth";
import type { Tilia } from "tilia";
import { fail, success, type Repo } from "../interface/repo";
import type { Todo } from "../model/todo";

export function memoryStore(
  initialTodos: Todo[] = [],
  initialSettings = {
    ["todos.filter"]: "all",
    ["display.darkMode"]: "false",
  } as Record<string, string>
): (ctx: Tilia, auth: Auth) => Repo {
  return ({ connect }: Tilia, _auth: Auth) => {
    // auth not used with local storage
    const repo: Repo = connect({
      t: "Ready",
      // Operations
      saveTodo: async (todo: Todo) => success(todo),
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
    return repo;
  };
}
