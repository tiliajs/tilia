// Import ReScript todos with gen types
import type { todo } from "./Todo.mjs";
import * as TodoModule from "./Todo.mjs";

// TypeScript type for the ReScript todo
export type Todo = todo;

export type Todos = {
  list: readonly Todo[];
  add: (todo: Todo) => void;
  toggle: (id: string) => void;
  remove: (id: string) => void;
  completedCount: number;
};

// Factory function to create a new todos instance
export const make = (): Todos => {
  return TodoModule.make();
};

// TypeScript helper functions that use ReScript gen types
export function addTodo(todos: Todos, id: string, title: string): void {
  const todo: Todo = TodoModule.makeTodo(id, title);
  todos.add(todo);
}

export function getCompletedCount(todos: Todos): number {
  return todos.completedCount;
}

export function toggleTodo(todos: Todos, id: string): void {
  todos.toggle(id);
}

export function removeTodo(todos: Todos, id: string): void {
  todos.remove(id);
}

export function getTodos(todos: Todos): readonly Todo[] {
  return todos.list;
}
