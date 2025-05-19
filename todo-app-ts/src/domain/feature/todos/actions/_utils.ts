import { isAuthenticated, type Auth } from "@interface/auth";
import { fail, type Repo } from "@interface/repo";
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

export async function saveTodo(auth: Auth, repo: Repo, atodo: Todo) {
  if (!isAuthenticated(auth.auth)) {
    return fail("Not authenticated");
  }
  const todo = { ...atodo, userId: auth.auth.user.id };
  return repo.saveTodo(todo);
}
