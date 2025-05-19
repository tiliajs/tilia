import { isAuthenticated, type Auth } from "@interface/auth";
import { fail, type Store } from "@interface/store";
import type { Todo } from "../../../model/todo";

export const filterKey = "todos.filter";

export function newTodo(): Todo {
  return {
    id: "",
    createdAt: "",
    userId: "", // userId is set on save.
    title: "",
    completed: false,
  };
}

export async function saveTodo(auth: Auth, store: Store, atodo: Todo) {
  if (!isAuthenticated(auth.auth)) {
    return fail("Not authenticated");
  }
  const todo = { ...atodo, userId: auth.auth.user.id };
  return store.saveTodo(todo);
}
