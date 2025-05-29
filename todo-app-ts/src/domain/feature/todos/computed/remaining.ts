import type { Todos } from "src/domain/api/feature/todos";
import { isLoaded } from "src/domain/api/model/loadable";

export function remaining(todos: Todos): number {
  const { data } = todos;
  if (isLoaded(data)) {
    return data.value.filter((t) => !t.completed).length;
  }
  return 0;
}
