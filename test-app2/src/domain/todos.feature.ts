import { make, addTodo, getCompletedCount, toggleTodo, removeTodo, getTodos, type Todos } from "./todos";
import { expect } from "vitest";
import { Given } from "vitest-bdd";

Given("I have no todos", function ({ When, Then }) {
  // Create a new todos instance for each scenario (enables parallelism)
  const todos = make();

  When("I add a todo with id {string} and title {string}", (id: string, title: string) => {
    addTodo(todos, id, title);
  });

  When("I toggle todo {string}", (id: string) => {
    toggleTodo(todos, id);
  });

  When("I remove todo {string}", (id: string) => {
    removeTodo(todos, id);
  });

  Then("I should have {number} todos", (count: number) => {
    expect(getTodos(todos)).toHaveLength(count);
  });

  Then("todo {string} should be completed", (id: string) => {
    const todo = getTodos(todos).find((t) => t.id === id);
    expect(todo?.completed).toBe(true);
  });

  Then("completed count should be {number}", (count: number) => {
    expect(getCompletedCount(todos)).toBe(count);
  });

  Then("todo {string} should not be completed", (id: string) => {
    const todo = getTodos(todos).find((t) => t.id === id);
    expect(todo?.completed).toBe(false);
  });
});
