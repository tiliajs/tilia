import { makeAuth } from "src/domain/feature/auth";
import { makeDisplay } from "src/domain/feature/display";
import { memoryStore } from "src/service/repo/memory";
import { expect } from "vitest";
import { Given } from "@epure/vitest";

Given("I have a display", ({ step }) => {
  const auth = makeAuth();
  const display = makeDisplay(memoryStore(auth, []));

  step("I set dark mode to {string}", (mode: "dark" | "light") => {
    display.setDarkMode(mode === "dark");
  });

  step("I should see dark mode", () => {
    expect(display.darkMode).to.be.true;
  });

  step("I should see light mode", () => {
    expect(display.darkMode).to.be.false;
  });
});
