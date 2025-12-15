import "@testing-library/react/dont-cleanup-after-each";
import { render, within, waitFor, act } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { expect } from "vitest";
import { Given } from "vitest-bdd";
import { make as TodoList } from "./TodoList.gen";
import { make as makeTodos, makeTodo } from "../domain/Todo.gen";

Given("I render the TodoList component", function ({ When, Then }) {
  // 1. Create a detached container for strict isolation
  const host = document.createElement("div");
  // Attach to body to ensure user events (focus/click) work correctly
  document.body.appendChild(host);

  // 2. Create isolated domain state
  const todos = makeTodos();

  // 3. Render specifically into OUR host
  render(<TodoList todos={todos} />, { container: host });

  // 4. Create a scoped 'screen' that only sees our host
  const screen = within(host);

  When("I add todo {string} with title {string}", async (id: string, title: string) => {
    await act(async () => {
      // Direct ReScript API usage
      const todo = makeTodo(id, title);
      todos.add(todo);
    });
  });

  When("I click toggle for todo {string}", async (title: string) => {
    const user = userEvent.setup();
    // Use regex to match either "Complete title" or "Undo title"
    await user.click(screen.getByRole("button", { name: new RegExp(`(Complete|Undo) ${title}`) }));
  });

  When("I click remove for todo {string}", async (title: string) => {
    const user = userEvent.setup();
    await user.click(screen.getByRole("button", { name: `Remove ${title}` }));
  });

  Then("I should see total {string}", async (expected: string) => {
    await waitFor(() => {
      expect(screen.getByRole("status", { name: "Total Count" })).toHaveTextContent(`Total: ${expected}`);
    });
  });

  Then("I should see completed {string}", async (expected: string) => {
    await waitFor(() => {
      expect(screen.getByRole("status", { name: "Completed Count" })).toHaveTextContent(`Completed: ${expected}`);
    });
  });

  Then("I should see todo {string}", async (title: string) => {
    // List item should exist with aria-label matching title
    await waitFor(() => {
      expect(screen.getByRole("listitem", { name: title })).toBeInTheDocument();
    });
  });

  Then("I should not see todo {string}", (title: string) => {
    expect(screen.queryByRole("listitem", { name: title })).not.toBeInTheDocument();
  });
});
