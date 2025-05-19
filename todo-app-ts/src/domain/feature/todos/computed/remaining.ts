import type { Todos } from "@interface/todos";
import { isLoaded } from "@model/loadable";

export function remaining(todos: Todos): number {
  const { data } = todos;
  if (isLoaded(data)) {
    return data.value.filter((t) => !t.completed).length;
  }
  return 0;
}
