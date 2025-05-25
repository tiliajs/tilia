import tailwind from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import tsPaths from "vite-tsconfig-paths";

// https://vite.dev/config/
export default defineConfig({
  build: {
    sourcemap: true,
  },
  base: process.env.VITE_TODO_APP_TS || "/",
  plugins: [react(), tailwind(), tsPaths()],
});
