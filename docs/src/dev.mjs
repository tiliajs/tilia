import path from "node:path";
import { fileURLToPath } from "node:url";
import chokidar from "chokidar";
import { build } from "./build.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
let building = false;
let pending = false;

async function rebuild() {
  if (building) {
    pending = true;
    return;
  }
  building = true;
  try {
    await build();
    console.log("Documentation rebuilt");
  } catch (error) {
    console.error(error);
  } finally {
    building = false;
    if (pending) {
      pending = false;
      await rebuild();
    }
  }
}

await rebuild();
chokidar
  .watch([path.join(root, "content"), path.join(root, "assets")], { ignoreInitial: true })
  .on("all", rebuild);
