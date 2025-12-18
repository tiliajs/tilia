import "@testing-library/react/dont-cleanup-after-each";
import {render, within, waitFor} from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import {expect} from "vitest";
import {Given} from "vitest-bdd";
import {CounterView} from "../../src/view/CounterView";
import {make} from "../../src/domain/Counter.gen";

Given("I render the Counter component", async function ({When, Then}) {
  const counter = make();
  const {container} = render(<CounterView counter={counter} />);
  const withinScreen = within(container);

  // Wait for initial render
  await withinScreen.findByRole("status", {name: "Value"});

  const user = userEvent.setup();

  When("I click the increment button", async () => {
    await user.click(withinScreen.getByRole("button", {name: "Increment"}));
  });

  When("I click the decrement button", async () => {
    await user.click(withinScreen.getByRole("button", {name: "Decrement"}));
  });

  When("I set counter to {number}", async (value: number) => {
    for (let i = 0; i < value; i++) {
      await user.click(withinScreen.getByRole("button", {name: "Increment"}));
    }
  });

  Then("I should see value {string}", async (expected: string) => {
    await waitFor(() => {
      expect(withinScreen.getByRole("status", {name: "Value"})).toHaveTextContent(`Value: ${expected}`);
    });
  });

  Then("I should see double {string}", async (expected: string) => {
    await waitFor(() => {
      expect(withinScreen.getByRole("status", {name: "Double"})).toHaveTextContent(`Double: ${expected}`);
    });
  });
});
