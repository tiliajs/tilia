import type { Todos } from "@feature/todos";

export function toggle(todos: Todos) {
  return (id: string) => {
    const todo = todos.data.find((t) => t.id === id);
    if (todo) {
      todo.completed = !todo.completed;
      todos.repo.saveTodo(todo);
    }
  };
}
