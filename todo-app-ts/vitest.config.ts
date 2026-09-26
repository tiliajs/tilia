import tsconfigPaths from "vite-tsconfig-paths";
import { epureVitest } from "@epure/vitest";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [epureVitest(), tsconfigPaths()],
  test: {
    pool: "threads",
    include: ["src/domain/test/**/*.feature", "src/domain/test/**/*.spec.ts"],
  },
});
