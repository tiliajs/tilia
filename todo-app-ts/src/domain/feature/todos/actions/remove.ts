import type { Todos } from "src/domain/api/feature/todos";
import { isLoaded } from "src/domain/api/model/loadable";
import { isSuccess, type RepoReady } from "src/domain/api/service/repo";

export async function remove(repo: RepoReady, todos: Todos, id: string) {
  if (isLoaded(todos.data)) {
    const result = await repo.removeTodo(id);
    if (isSuccess(result)) {
      todos.data.value = todos.data.value.filter((t) => t.id !== id);
    }
    // FIXME: handle error
  }
}
