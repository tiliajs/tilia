import { useTilia } from "@tilia/react";
import { make, type Todo, type Todos } from "../domain/todos";
import { useMemo } from "react";

type TodoListProps = {
  todos?: Todos;
};

export function TodoList({ todos: todosProp }: TodoListProps = {}) {
  useTilia();
  
  // Create todos instance once per component mount, or use provided prop
  const todos: Todos = useMemo(() => todosProp ?? make(), [todosProp]);
  const todoList: readonly Todo[] = todos.list;

  return (
    <div>
      <div role="status" aria-label="Total Count">Total: {todoList.length}</div>
      <div role="status" aria-label="Completed Count">Completed: {todos.completedCount}</div>
      <ul role="list" aria-label="Todos">
        {todoList.map((todo: Todo) => (
          <li key={todo.id} role="listitem" aria-label={todo.title}>
            <span>{todo.title}</span>
            <button
              onClick={() => todos.toggle(todo.id)}
              aria-label={`${todo.completed ? "Undo" : "Complete"} ${todo.title}`}
            >
              {todo.completed ? "Undo" : "Complete"}
            </button>
            <button
              onClick={() => todos.remove(todo.id)}
              aria-label={`Remove ${todo.title}`}
            >
              Remove
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
