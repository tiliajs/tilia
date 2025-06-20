import tsconfigPaths from "vite-tsconfig-paths";
import { vitestBdd } from "vitest-bdd";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [vitestBdd(), tsconfigPaths()],
  test: {
    pool: "threads",
    include: ["src/domain/test/**/*.feature", "src/domain/test/**/*.spec.ts"],
  },
});
