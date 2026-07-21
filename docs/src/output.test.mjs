import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { access, readFile, readdir } from "node:fs/promises";

const dist = path.resolve("dist");

async function htmlFiles(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) files.push(...(await htmlFiles(file)));
    else if (entry.name.endsWith(".html")) files.push(file);
  }
  return files;
}

async function exists(file) {
  try {
    await access(file);
    return true;
  } catch {
    return false;
  }
}

async function target(file, href) {
  const [rawPath, hash = ""] = href.split("#", 2);
  let target = rawPath
    ? rawPath.startsWith("/")
      ? path.join(dist, rawPath)
      : path.resolve(path.dirname(file), rawPath)
    : file;

  if (target.endsWith(path.sep)) target = path.join(target, "index.html");
  if (!(await exists(target)) && !path.extname(target) && (await exists(`${target}.html`))) {
    target = `${target}.html`;
  }
  return { target, hash: decodeURIComponent(hash) };
}

test("generated local links and anchors resolve", async () => {
  const missing = [];
  for (const file of await htmlFiles(dist)) {
    const html = await readFile(file, "utf8");
    const hrefs = [...html.matchAll(/\bhref="([^"]+)"/g)].map((match) => match[1]);
    for (const href of hrefs) {
      if (/^(?:[a-z]+:|\/\/)/i.test(href) || href === "#") continue;
      const resolved = await target(file, href);
      if (!(await exists(resolved.target))) {
        missing.push(`${path.relative(dist, file)}: ${href}`);
        continue;
      }
      if (!resolved.hash || !resolved.target.endsWith(".html")) continue;
      const targetHtml = await readFile(resolved.target, "utf8");
      const escaped = resolved.hash.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      if (!new RegExp(`\\bid=["']${escaped}["']`).test(targetHtml)) {
        missing.push(`${path.relative(dist, file)}: ${href}`);
      }
    }
  }

  assert.deepEqual(missing, []);
});
