import { make, makeTodo, type todos as Todos } from "./Todo.gen";
import { expect } from "vitest";
import { Given } from "vitest-bdd";

Given("I have no todos", function ({ When, Then }) {
  // Create a new todos instance for each scenario (enables parallelism)
  const todos = make();

  When("I add a todo with id {string} and title {string}", (id: string, title: string) => {
    todos.add(makeTodo(id, title));
  });

  When("I toggle todo {string}", (id: string) => {
    todos.toggle(id);
  });

  When("I remove todo {string}", (id: string) => {
    todos.remove(id);
  });

  Then("I should have {number} todos", (count: number) => {
    expect(todos.list).toHaveLength(count);
  });

  Then("todo {string} should be completed", (id: string) => {
    const todo = todos.list.find((t) => t.id === id);
    expect(todo?.completed).toBe(true);
  });

  Then("completed count should be {number}", (count: number) => {
    expect(todos.completedCount).toBe(count);
  });

  Then("todo {string} should not be completed", (id: string) => {
    const todo = todos.list.find((t) => t.id === id);
    expect(todo?.completed).toBe(false);
  });
});
