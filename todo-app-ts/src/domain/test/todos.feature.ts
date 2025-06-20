import { makeTodos } from "src/domain/feature/todos/todos";
import { readyMemoryStore } from "src/service/repo/memory";
import { observe } from "tilia";
import { expect } from "vitest";
import { Given } from "vitest-bdd";

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

Given("I have todos", async function ({ When, Then }, table: string[][]) {
  const todos = makeTodos(readyMemoryStore("main", todosFromTable(table)));
  await isTrue(() => todos.t === "Loaded");
  function todo(title: string) {
    const todo = todos.list.find((t) => t.title === title);
    if (!todo) {
      throw new Error(`Todo ${JSON.stringify(title)} not found`);
    }
    return todo;
  }

  When("I create {string}", async (title: string) => {
    await todos.save({
      id: "",
      title,
      completed: false,
      createdAt: "",
      userId: "",
    });
  });

  When("I toggle {string}", (title: string) => {
    todos.toggle(todo(title).id);
  });

  When("I remove {string}", (title: string) => {
    todos.remove(todo(title).id);
  });

  When("I edit {string}", (title: string) => {
    todos.edit(todo(title).id);
  });

  When("I set title to {string}", (title: string) => {
    todos.setTitle(title);
  });

  When("I save", async () => {
    await todos.save(todos.selected);
  });

  Then("{string} should be selected", (title: string) => {
    expect(todos.selected).to.equal(todo(title));
  });

  Then("I should see {string} in the list", (title: string) => {
    const todo = todos.list.find((t) => t.title === title);
    expect(todo).to.not.be.undefined;
  });

  Then("I should not see {string} in the list", (title: string) => {
    const todo = todos.list.find((t) => t.title === title);
    expect(todo).to.be.undefined;
  });

  Then("{string} should be done", (title: string) => {
    const todo = todos.list.find((t) => t.title === title);
    expect(todo?.completed).to.be.true;
  });

  Then("{string} should be not done", (title: string) => {
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
