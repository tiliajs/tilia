import { fail, success, type Repo } from "../interface/repo";
import { type Context } from "../model/context";
import type { Todo } from "../model/todo";

export function memoryStore(
  { connect }: Context,
  initialTodos: Todo[] = [],
  initialSettings = {
    ["todos.filter"]: "all",
    ["display.darkMode"]: "false",
  } as Record<string, string>
): Repo {
  // auth not used with local storage
  const repo: Repo = connect({
    state: { t: "Ready" },
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
}
