import react from "@vitejs/plugin-react";
import { vitestBdd } from "vitest-bdd";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [react(), vitestBdd({ concurrent: false })],
  test: {
    globals: true,
    environment: "jsdom",
    include: ["test/**/*.feature"],
    setupFiles: ["./test/setup.ts"],
  },
});
