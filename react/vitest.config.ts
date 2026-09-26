import react from "@vitejs/plugin-react";
import { epureVitest } from "@epure/vitest";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [react(), epureVitest({ concurrent: false })],
  test: {
    globals: true,
    environment: "jsdom",
    include: ["test/**/*.feature"],
    setupFiles: ["./test/setup.ts"],
  },
});
