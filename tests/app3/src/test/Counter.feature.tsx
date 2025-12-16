import "@testing-library/react/dont-cleanup-after-each";
import { render, within, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { expect } from "vitest";
import { Given } from "vitest-bdd";
import { Counter, CounterLeaf } from "../view/Counter";
import { make } from "../domain/counter";

Given("I render the {string} component", async function ({ When, Then }, comp: string) {
  const counter = make();
  const Component = comp === "Counter" ? Counter : CounterLeaf;
  const { container } = render(<Component counter={counter} />);
  const withinScreen = within(container);

  // Wait for initial render
  await withinScreen.findByRole("status", { name: "Value" });

  const user = userEvent.setup();

  When("I click the increment button", async () => {
    await user.click(withinScreen.getByRole("button", { name: "Increment" }));
  });

  When("I click the decrement button", async () => {
    await user.click(withinScreen.getByRole("button", { name: "Decrement" }));
  });

  When("I set counter to {number}", async (value: number) => {
    // Direct mutation
    counter.value = value;
  });

  Then("I should see value {string}", async (expected: string) => {
    await waitFor(() => {
      expect(withinScreen.getByRole("status", { name: "Value" })).toHaveTextContent(`Value: ${expected}`);
    });
  });

  Then("I should see double {string}", async (expected: string) => {
    await waitFor(() => {
      expect(withinScreen.getByRole("status", { name: "Double" })).toHaveTextContent(`Double: ${expected}`);
    });
  });
});
