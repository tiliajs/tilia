import { describe, expect, it } from "vitest";
import { makeContext } from "../../model/context";
import { loaded } from "../../model/loadable";
import type { Todo } from "../../model/todo";
import { memoryStore } from "../../repo/memory";
import { makeAuth } from "../auth";
import { makeDisplay } from "../display";
import { makeTodos } from "./todos";

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
  const ctx = makeContext((fn) => fn()); // Immediate flush
  const auth = makeAuth(ctx);
  const store = memoryStore(ctx, initialTodos);
  const display = makeDisplay(ctx, store);
  const todos = makeTodos(ctx, auth, store);
  auth.login({ id: "main", name: "Main" });
  const app = ctx.connect({ todos, auth, store, display });
  return new Promise<typeof app>((resolve) => {
    ctx.observe(() => {
      if (loaded(app.todos.data)) {
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
    const todo = await todos.save({
      id: "",
      createdAt: "",
      title: "Buy milk",
      completed: false,
      userId: "",
    });
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
    const todo = await todos.save({
      id: "",
      createdAt: "",
      title: "Buy milk",
      completed: false,
      userId: "",
    });
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

  it("should update list on filters change", async () => {
    const { todos } = await setup();
    expect(todos.list).toEqual([plants, rice, hug]);
    await todos.setFilter("active");
    expect(todos.list).toEqual([plants, hug]);
  });

  it("should update list on toggle", async () => {
    const { todos } = await setup();
    await todos.setFilter("active");
    expect(todos.list).toEqual([plants, hug]);
    todos.toggle("2");
    expect(todos.list).toEqual([plants]);
  });
});
