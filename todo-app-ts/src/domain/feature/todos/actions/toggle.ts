import type { RepoReady } from "@interface/repo";
import type { Todos } from "@interface/todos";
import { isLoaded } from "@model/loadable";

export function toggle(repo: RepoReady, todos: Todos, id: string) {
  if (isLoaded(todos.data)) {
    const todo = todos.data.value.find((t) => t.id === id);
    if (todo) {
      todo.completed = !todo.completed;
      repo.saveTodo(todo);
    }
  }
}
