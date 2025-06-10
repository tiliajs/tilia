import type { Todos } from "src/domain/api/feature/todos";
import { isLoaded } from "src/domain/api/model/loadable";
import { isSuccess, type RepoReady } from "src/domain/api/service/repo";

export async function remove(repo: RepoReady, todos: Todos, id: string) {
  const data = todos.data_.valuex;
  if (isLoaded(data)) {
    const result = await repo.removeTodo(id);
    if (isSuccess(result)) {
      data.value = data.value.filter((t) => t.id !== id);
    }
    // FIXME: handle error
  }
}
