import type { Todo } from "../model/todo";

export type Success<T> = { t: "Success"; value: T };
export type Fail = { t: "Fail"; message: string };

export type Result<T> = Success<T> | Fail;

export type Repo = {
  state: { t: "Ready" }

  // Operations
  saveTodo: (todo: Todo) => Promise<Result<Todo>>;
  removeTodo: (id: string) => Promise<Result<string>>;
  fetchTodos: (userId: string) => Promise<Result<Todo[]>>;
  saveSetting: (key: string, value: string) => Promise<Result<string>>;
  fetchSetting: (key: string) => Promise<Result<string>>;
};

export function success<T>(value: T): Success<T> {
  return { t: "Success", value };
}

export function fail(message: string): Fail {
  return { t: "Fail", message };
}

export function isSuccess<T>(result: Result<T>): result is Success<T> {
  return result.t === "Success";
}

export function isFail<T>(result: Result<T>): result is Fail {
  return result.t === "Fail";
}

export function isReady(repo: Repo): boolean {
  return repo.state.t === "Ready";
}
