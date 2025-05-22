import { type AuthAuthenticated } from "@interface/auth";
import { type RepoReady } from "@interface/repo";
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

export async function saveTodo(
  auth: AuthAuthenticated,
  repo: RepoReady,
  atodo: Todo
) {
  const todo = { ...atodo, userId: auth.user.id };
  return repo.saveTodo(todo);
}
