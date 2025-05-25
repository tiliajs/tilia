import { makeApp } from "@feature/app";
import { isAppReady, type AppReady } from "@interface/app";
import { memoryStore } from "src/domain/repo/memory";
import { observe } from "tilia";
import { describe, expect, it } from "vitest";
import { loaded } from "../../model/loadable";
import type { Todo } from "../../model/todo";

const tick = () => new Promise((resolve) => setTimeout(resolve, 0));

const rice: Todo = {
  id: "1",
  createdAt: "2025-05-18T20:15:03.000Z",
  title: "Cook rice",
  userId: "main",
  completed: true,
};
const hug: Todo = {
  id: "2",
  createdAt: "2025-05-18T20:15:00.000Z",
  title: "Give a hug",
  userId: "main",
  completed: false,
};
const plants: Todo = {
  id: "3",
  createdAt: "2025-05-18T21:13:00.000Z",
  title: "Water the plants",
  userId: "main",
  completed: false,
};

const baseTodos = () => [hug, rice, plants];

async function setup(initialTodos: Todo[] = baseTodos()) {
  const { app_, auth_ } = makeApp();

  if (app_.value.auth.t !== "Authenticated") {
    const repo = memoryStore(auth_, initialTodos);
    app_.value.auth.login(repo, { id: "main", name: "Main" });
  }

  return new Promise<AppReady>((resolve) => {
    observe(() => {
      const app = app_.value;
      if (isAppReady(app) && app.todos.data.t === "Loaded") {
        resolve(app);
      }
    });
  });
}

describe("Todos", () => {
  it("should set data to loaded after login", async () => {
    const { todos } = await setup([]);
    expect(todos.data).toEqual(loaded([]));
  });

  it("should set id to uuid on save", async () => {
    const { todos } = await setup();
    await todos.save({
      id: "",
      createdAt: "",
      title: "Buy milk",
      completed: false,
      userId: "",
    });

    const todo = todos.list[0];
    expect(todo.id).toMatch(
      // uuid
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
    );
    expect(todo.createdAt).toMatch(
      // ISO 8601
      /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z$/
    );
  });

  it("should add new todo to list", async () => {
    const { todos } = await setup([]);
    await todos.save({
      id: "",
      createdAt: "",
      title: "Buy milk",
      completed: false,
      userId: "",
    });

    const todo = todos.list[0];
    expect(todos.list).toEqual([
      {
        id: todo.id,
        createdAt: todo.createdAt,
        title: "Buy milk",
        completed: false,
        userId: "main",
      },
    ]);
  });

  it("should not add empty todo", async () => {
    const { todos } = await setup([]);
    await todos.save({
      id: "",
      createdAt: "",
      title: "",
      completed: false,
      userId: "",
    });

    expect(todos.list).toEqual([]);
  });

  it("should update list on filters change", async () => {
    const { todos } = await setup();
    expect(todos.list).toEqual([plants, rice, hug]);
    todos.setFilter("active");
    await tick();
    expect(todos.list).toEqual([plants, hug]);
  });

  it("should update list on toggle", async () => {
    const { todos } = await setup();
    todos.setFilter("active");
    await tick();
    expect(todos.list).toEqual([plants, hug]);
    todos.toggle("2");
    await tick();
    expect(todos.list).toEqual([plants]);
  });
});
