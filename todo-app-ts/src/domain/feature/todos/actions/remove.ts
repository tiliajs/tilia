import type { Todos } from "@feature/todos";
import { isSuccess } from "@service/repo";

export function remove(todos: Todos) {
  const { repo } = todos;
  return async (id: string) => {
    const result = await repo.removeTodo(id);
    if (isSuccess(result)) {
      todos.data = todos.data.filter((t) => t.id !== id);
    }
  };
}
