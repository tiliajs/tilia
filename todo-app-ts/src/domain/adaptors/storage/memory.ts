import { fail, success, type Store } from "../../ports/store";
import { type Context } from "../../tilia";
import type { Todo } from "../../types/todo";

export function memoryStore(
  { connect }: Context,
  initialTodos: Todo[] = [],
  initialSettings = {
    ["todos.filter"]: "all",
    ["display.darkMode"]: "false",
  } as Record<string, string>
): Store {
  // auth not used with local storage
  const store: Store = connect({
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
  return store;
}
