import type { Todo } from "../../../api/model/todo";

export const filterKey = "todos-filter";

export function newTodo(): Todo {
  return {
    id: "",
    createdAt: "",
    userId: "", // userId is set on save.
    title: "",
    completed: false,
  };
}
