import react from "@vitejs/plugin-react";
import {vitestBdd} from "vitest-bdd";
import {defineConfig} from "vitest/config";
import {existsSync} from "fs";
import {join, dirname} from "path";
import {fileURLToPath} from "url";

// Out-of-source steps resolver for BDD tests

const base = dirname(fileURLToPath(import.meta.url));
const toLib = (p: string) => p.replace(base, `${base}/lib/es6`);

function baseResolver(path: string): string | null {
  for (const ext of [".tsx", ".ts", ".js", ".mjs", ".cjs"]) {
    const p = `${path}${ext}`;
    if (existsSync(p)) {
      return p;
    }
  }
  return null;
}

function stepsResolver(path: string): string | null {
  // Resolves to a specific steps file
  // from /foo/bar.feature
  // to   /foo/bar.feature[.tsx|.ts|.js|...]
  // or   /foo/bar.steps[.tsx|.ts|.js|...]
  // or   /foo/barSteps[.tsx|.ts|.js|...]
  for (const r of [".feature", ".steps", "Steps"]) {
    const basePath = path.replace(/\.feature$/, r);
    const resolved = baseResolver(basePath) || baseResolver(toLib(basePath));
    if (resolved) {
      return resolved;
    }
  }
  // Resolves to a common steps file in the directory:
  // from /foo/bar.feature
  // to   /foo/steps[.tsx|.ts|.js|...]
  const dir = dirname(path);
  return baseResolver(join(dir, "steps"));
}

export default defineConfig({
  plugins: [react(), vitestBdd({stepsResolver, concurrent: false})],
  test: {
    globals: true,
    environment: "jsdom",
    include: ["test/**/*.feature"],
    setupFiles: ["./test/setup.ts"],
  },
});
