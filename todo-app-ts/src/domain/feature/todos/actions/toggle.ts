import type { Todos } from "src/domain/api/feature/todos";
import { isLoaded } from "src/domain/api/model/loadable";
import type { RepoReady } from "src/domain/api/service/repo";

export function toggle(_repo: RepoReady, todos: Todos, id: string) {
  const data = todos.data_.valuex;
  if (isLoaded(data)) {
    const todo = data.value.find((t) => t.id === id);
    if (todo) {
      todo.completed = !todo.completed;
      // repo.saveTodo(todo);
    }
  }
}
