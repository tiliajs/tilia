import { isLoaded } from "@entity/loadable";
import type { Todos } from "@feature/todos";

export function remaining(todos: Todos): number {
  const data = todos.data_.value;
  if (isLoaded(data)) {
    return data.value.filter((t) => !t.completed).length;
  }
  return 0;
}
