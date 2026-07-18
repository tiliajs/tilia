import path from "node:path";
import { fileURLToPath } from "node:url";
import chokidar from "chokidar";
import { copyAssets, runBuild } from "./build.mjs";
import { queue } from "./queue.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const enqueue = queue();

async function main() {
  await enqueue(runBuild);
  chokidar.watch([path.join(root, "content"), path.join(root, "assets")], { ignoreInitial: true }).on(
    "all",
    async (event, file) => {
      const rel = path.relative(root, file);
      if (rel.startsWith("assets/")) {
        console.log(`${event}: ${rel} — copying assets`);
        await enqueue(copyAssets);
        return;
      }
      if (rel.startsWith("content/")) {
        console.log(`${event}: ${rel} — rebuilding`);
        await enqueue(runBuild);
      }
    }
  );
}

main();
