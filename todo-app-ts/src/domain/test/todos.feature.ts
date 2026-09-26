import { makeTodos } from "src/domain/feature/todos/todos";
import { readyMemoryStore } from "src/service/repo/memory";
import { expect } from "vitest";
import { Given } from "@epure/vitest";

/*
// await isTrue(() => todos.list.length > 0);

import { observe } from "tilia";
const PREDICATE_TIMEOUT = 1000;

async function isTrue(fn: () => boolean) {
  return new Promise<void>((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(`Predicate did not become true in ${PREDICATE_TIMEOUT / 1000} s`);
    }, PREDICATE_TIMEOUT);

    observe(() => {
      if (fn()) {
        clearTimeout(timeout);
        resolve();
      }
    });
  });
}
*/

Given("I have todos", async function ({ step }, table: string[][]) {
  const data = todosFromTable(table);
  const todos = makeTodos(readyMemoryStore("main", data), data);
  function todo(title: string) {
    const todo = todos.list.find((t) => t.title === title);
    if (!todo) {
      throw new Error(`Todo ${JSON.stringify(title)} not found`);
    }
    return todo;
  }

  step("I create {string}", async (title: string) => {
    await todos.save({
      id: "",
      title,
      completed: false,
      createdAt: "",
      userId: "",
    });
  });

  step("I toggle {string}", (title: string) => {
    todos.toggle(todo(title).id);
  });

  step("I remove {string}", (title: string) => {
    todos.remove(todo(title).id);
  });

  step("I edit {string}", (title: string) => {
    todos.edit(todo(title).id);
  });

  step("I set title to {string}", (title: string) => {
    todos.setTitle(title);
  });

  step("I save", async () => {
    await todos.save(todos.selected);
  });

  step("{string} should be selected", (title: string) => {
    expect(todos.selected).to.equal(todo(title));
  });

  step("I should see {string} in the list", (title: string) => {
    const todo = todos.list.find((t) => t.title === title);
    expect(todo).to.not.be.undefined;
  });

  step("I should not see {string} in the list", (title: string) => {
    const todo = todos.list.find((t) => t.title === title);
    expect(todo).to.be.undefined;
  });

  step("{string} should be done", (title: string) => {
    const todo = todos.list.find((t) => t.title === title);
    expect(todo?.completed).to.be.true;
  });

  step("{string} should be not done", (title: string) => {
    const todo = todos.list.find((t) => t.title === title);
    expect(todo?.completed).to.be.false;
  });
});

function todosFromTable(table: string[][]) {
  const header = table[0];
  const createdAt = new Date().toISOString();
  return table
    .slice(1)
    .map((row) => Object.fromEntries(header.map((h, i) => [h, row[i]])))
    .map((row) => ({
      id: (row.title || "").replace(/\s+/g, "-").toLowerCase(),
      createdAt,
      title: "",
      userId: "main",
      ...row,
      completed: row.completed === "true",
    }));
}
