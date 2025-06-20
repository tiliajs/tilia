import { makeAuth } from "src/domain/feature/auth";
import { makeDisplay } from "src/domain/feature/display";
import { memoryStore } from "src/service/repo/memory";
import { expect } from "vitest";
import { Given } from "vitest-bdd";

Given("I have a display", ({ When, Then }) => {
  const auth = makeAuth();
  const display = makeDisplay(memoryStore(auth, []));

  When("I set dark mode to {string}", (mode: "dark" | "light") => {
    display.setDarkMode(mode === "dark");
  });

  Then("I should see dark mode", () => {
    expect(display.darkMode).to.be.true;
  });

  Then("I should see light mode", () => {
    expect(display.darkMode).to.be.false;
  });
});
