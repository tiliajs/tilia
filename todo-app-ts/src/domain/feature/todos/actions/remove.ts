import { isLoaded } from "@entity/loadable";
import type { Todos } from "@feature/todos";
import { type RepoReady, isSuccess } from "@service/repo";

export async function remove(repo: RepoReady, todos: Todos, id: string) {
  const data = todos.data_.value;
  if (isLoaded(data)) {
    const result = await repo.removeTodo(id);
    if (isSuccess(result)) {
      data.value = data.value.filter((t) => t.id !== id);
    }
  }
}
