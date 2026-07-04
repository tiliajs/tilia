import tailwind from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  build: {
    sourcemap: true,
  },
  base: process.env.VITE_CLAIMS_APP_TS || "/",
  plugins: [react(), tailwind()],
});
