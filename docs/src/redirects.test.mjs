import test from "node:test";
import assert from "node:assert/strict";
import os from "node:os";
import path from "node:path";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { guideRedirectScript, redirects, renderRedirects } from "./redirects.mjs";

test("maps legacy pages and fragments", () => {
  const docs = redirects.find((redirect) => redirect.file === "docs.html");
  const compare = redirects.find((redirect) => redirect.file === "compare.html");

  assert.equal(docs.target, "./guide.html");
  assert.equal(docs.hashes["#tilia"], "./api.html#tilia");
  assert.equal(docs.hashes["#ddd"], "./guide.html#drawn-before-built");
  assert.equal(compare.target, "./guide.html#drawn-before-built");
});

test("maps legacy guide fragments on the current guide", () => {
  assert.match(guideRedirectScript, /#react/);
  assert.match(guideRedirectScript, /\.\/guide\.html#tilia-in-react/);
  assert.match(guideRedirectScript, /\/query\//);
});

test("writes accessible static redirect documents", async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), "tilia-redirects-"));
  try {
    await renderRedirects(dir);
    const html = await readFile(path.join(dir, "compare.html"), "utf8");

    assert.match(html, /http-equiv="refresh"/);
    assert.match(html, /rel="canonical" href="https:\/\/tiliajs\.dev\/guide\.html#drawn-before-built"/);
    assert.match(html, /window\.location\.replace/);
    assert.match(html, /Page moved/);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});
