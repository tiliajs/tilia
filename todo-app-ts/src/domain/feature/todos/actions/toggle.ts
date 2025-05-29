import type { Todos } from "src/domain/api/feature/todos";
import { isLoaded } from "src/domain/api/model/loadable";
import type { RepoReady } from "src/domain/api/service/repo";

export function toggle(repo: RepoReady, todos: Todos, id: string) {
  if (isLoaded(todos.data)) {
    const todo = todos.data.value.find((t) => t.id === id);
    if (todo) {
      todo.completed = !todo.completed;
      repo.saveTodo(todo);
    }
  }
}
