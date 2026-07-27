import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { access, readFile } from "node:fs/promises";

const root = path.resolve(".");

async function generated(file) {
  return readFile(path.join(root, "dist", file), "utf8");
}

test("uses the published minidoc beta API", async () => {
  const minidoc = await import("@epure/minidoc");
  assert.equal(typeof minidoc.run, "function");
  assert.equal(typeof minidoc.nodeFs, "function");
});

test("keeps home sources as body fragments", async () => {
  for (const file of [
    "content/tilia/home/index.html",
    "content/query/home/index.html",
  ]) {
    const html = await readFile(path.join(root, file), "utf8");
    assert.match(html, /<section class="hero"/);
    assert.doesNotMatch(html, /<!doctype|<html|<body|<main|<header class="top"|<footer class="foot"|<script/);
  }
});

test("generates both home pages from fragments", async () => {
  const tilia = await generated("index.html");
  const query = await generated("query/index.html");

  assert.equal((tilia.match(/<main(?:\s|>)/g) || []).length, 1);
  assert.equal((query.match(/<main(?:\s|>)/g) || []).length, 1);
  assert.match(tilia, /<title>tilia — Domain-Driven State Management<\/title>/);
  assert.match(tilia, /<h1 id="hero-title">Domain-Driven State&nbsp;Management<\/h1>/);
  assert.match(query, /<title>@tilia\/query — Remote Data That Feels Local<\/title>/);
  assert.match(query, /<h1 id="hero-title">Remote Data That Feels&nbsp;Local<\/h1>/);
  assert.doesNotMatch(query, /query XX/);
});

test("marks home navigation from the document config", async () => {
  const tilia = await generated("index.html");
  const query = await generated("query/index.html");
  const tiliaGuide = await generated("guide.html");
  const queryGuide = await generated("query/guide.html");

  assert.match(tilia, /href="\.\/index\.html" aria-current="page">Home<\/a>/);
  assert.match(query, /href="\.\/index\.html" aria-current="page">Home<\/a>/);
  assert.match(tiliaGuide, /href="\.\/guide\.html" aria-current="page">Guide<\/a>/);
  assert.match(queryGuide, /href="\.\/guide\.html" aria-current="page">Guide<\/a>/);
});

test("retains landing toggles and Tilia legacy guide hashes", async () => {
  const tilia = await generated("index.html");
  const query = await generated("query/index.html");
  const tiliaGuide = await generated("guide.html");
  const queryGuide = await generated("query/guide.html");

  for (const home of [tilia, query]) {
    assert.match(home, /getElementById\(["']hero-code["']\)/);
    assert.match(home, /setAttribute\(["']aria-pressed["']/);
  }
  assert.match(tiliaGuide, /Legacy guide anchors/);
  assert.match(tiliaGuide, /#react/);
  assert.doesNotMatch(queryGuide, /Legacy guide anchors/);
});

test("builds shared assets, LLM files, and redirects", async () => {
  for (const file of [
    "dist/style.css",
    "dist/fonts",
    "dist/llms.txt",
    "dist/query/llms.txt",
    "dist/docs.html",
    "dist/compare.html",
  ]) {
    await access(path.join(root, file));
  }

  const redirect = await generated("compare.html");
  assert.match(
    redirect,
    /rel="canonical" href="https:\/\/tiliajs\.dev\/guide\.html#drawn-before-built"/,
  );
});

test("keeps project-specific navigation styling", async () => {
  const css = await readFile(path.join(root, "assets/style.css"), "utf8");

  assert.match(css, /\.package-mark \{[\s\S]*?grid-template-columns: 72px 61px max-content;[\s\S]*?\}/);
  assert.match(
    css,
    /\.package-name\[aria-current="true"\] \.package-label \{[\s\S]*?font-size: 20px;[\s\S]*?font-weight: 600;/,
  );
  assert.match(
    css,
    /\.package-mark \.package-name\[aria-current="true"\] \{[\s\S]*?color: var\(--accent-ink\);/,
  );
});
