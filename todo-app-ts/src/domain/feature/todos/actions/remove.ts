import { isSuccess, type RepoReady } from "@interface/repo";
import type { Todos } from "@interface/todos";
import { isLoaded } from "@model/loadable";

export async function remove(repo: RepoReady, todos: Todos, id: string) {
  if (isLoaded(todos.data)) {
    const result = await repo.removeTodo(id);
    if (isSuccess(result)) {
      todos.data.value = todos.data.value.filter((t) => t.id !== id);
    }
    // FIXME: handle error
  }
}
