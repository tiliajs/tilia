import { isLoaded } from "@entity/loadable";
import type { Todos } from "@feature/todos";
import type { RepoReady } from "@service/repo";

export function toggle(_repo: RepoReady, todos: Todos, id: string) {
  const data = todos.data_.value;
  if (isLoaded(data)) {
    const todo = data.value.find((t) => t.id === id);
    if (todo) {
      todo.completed = !todo.completed;
      // repo.saveTodo(todo);
    }
  }
}
