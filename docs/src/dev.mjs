import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import chokidar from "chokidar";
import { copyAssets, runBuild } from "./build.mjs";

const require = createRequire(import.meta.url);
const liveServer = require("live-server");

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const distDir = path.join(root, "dist");
const port = 4175;

async function rebuild() {
  await runBuild();
}

function serve() {
  liveServer.start({
    host: "127.0.0.1",
    port,
    root: distDir,
    open: false,
    logLevel: 2,
    wait: 100,
  });
  console.log(`Dev server running at http://localhost:${port}`);
}

async function main() {
  await rebuild();
  serve();
  chokidar.watch([path.join(root, "content"), path.join(root, "assets")], { ignoreInitial: true }).on(
    "all",
    async (event, file) => {
      const rel = path.relative(root, file);
      if (rel.startsWith("assets/")) {
        console.log(`${event}: ${rel} — copying assets`);
        await copyAssets();
        return;
      }
      if (rel.startsWith("content/")) {
        console.log(`${event}: ${rel} — rebuilding`);
        await rebuild();
      }
    }
  );
}

main();
