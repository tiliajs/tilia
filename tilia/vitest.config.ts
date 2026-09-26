import { epureVitest } from "@epure/vitest";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [epureVitest()],
  test: {
    include: ["test/*_test.mjs", "test/**/*_test.mjs"],
  },
});
