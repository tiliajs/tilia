import { vitestBdd } from "vitest-bdd";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [vitestBdd()],
  test: {
    include: ["test/*_test.mjs", "test/**/*_test.mjs"],
  },
});
