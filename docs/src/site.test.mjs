import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { access, readFile } from "node:fs/promises";

const root = path.resolve(".");
const pages = [
  "index.html",
  "guide.html",
  "api.html",
  "errors.html",
  "query/index.html",
  "query/guide.html",
  "query/api.html",
  "react/index.html",
  "react/api.html",
];

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
    "content/react/home/index.html",
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
    "dist/react/llms.txt",
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

test("lists every package in the switcher, from the site root", async () => {
  const tilia = await generated("guide.html");
  const query = await generated("query/guide.html");
  const react = await generated("react/api.html");

  for (const html of [tilia, query, react]) {
    assert.match(html, /<span class="pkg-option__name">tilia<\/span>/);
    assert.match(html, /<span class="pkg-option__name">@tilia\/query<\/span>/);
    assert.match(html, /<span class="pkg-option__name">@tilia\/react<\/span>/);
    assert.match(html, /<span class="pkg-option__desc">Domain-driven state management<\/span>/);
    assert.match(html, /<span class="pkg-option__desc">Remote data that feels local<\/span>/);
    assert.match(html, /<span class="pkg-option__desc">Views that observe the domain<\/span>/);
  }

  assert.match(tilia, /class="pkg-option" role="option" href="\.\/index\.html"/);
  assert.match(tilia, /class="pkg-option" role="option" href="\.\/query\/index\.html"/);
  assert.match(query, /class="pkg-option" role="option" href="\.\.\/index\.html"/);
  assert.match(query, /class="pkg-option" role="option" href="\.\.\/query\/index\.html"/);
  assert.match(react, /class="pkg-option" role="option" href="\.\.\/react\/index\.html"/);
});

test("gives react a home and an API, and no guide", async () => {
  for (const page of ["react/index.html", "react/api.html"]) {
    const html = await generated(page);
    const nav = html.match(/<nav class="nav"[\s\S]*?<\/nav>/)[0];

    assert.match(html, /<body class="react">/, page);
    assert.match(nav, /href="\.\/index\.html"/, page);
    assert.match(nav, /href="\.\/api\.html"/, page);
    assert.doesNotMatch(nav, />Guide</, page);
  }

  for (const page of ["guide.html", "query/guide.html"]) {
    const nav = (await generated(page)).match(/<nav class="nav"[\s\S]*?<\/nav>/)[0];
    assert.match(nav, />Guide</, page);
  }
});

test("names the selected package on the trigger and checks it once", async () => {
  for (const page of pages) {
    const html = await generated(page);
    const name = page.startsWith("query/")
      ? "@tilia/query"
      : page.startsWith("react/")
        ? "@tilia/react"
        : "tilia";
    const options = [...html.matchAll(/<a class="pkg-option"[\s\S]*?<\/a>/g)].map((m) => m[0]);
    const selected = options.filter((option) => option.includes('aria-selected="true"'));

    assert.equal(options.length, 3, page);
    assert.equal(selected.length, 1, page);
    assert.match(selected[0], new RegExp(`<span class="pkg-option__name">${name.replace("/", "\\/")}<`), page);
    assert.ok(html.includes(`<span class="pkg-switcher__current">${name}</span>`), page);
    assert.match(html, /aria-haspopup="listbox" aria-expanded="false" aria-controls="pkg-menu"/, page);
  }
});

test("keeps aria-current for the current page alone", async () => {
  for (const page of pages) {
    const html = await generated(page);
    assert.doesNotMatch(html, /aria-current="true"/, page);
  }

  const api = await generated("query/api.html");
  assert.equal((api.match(/aria-current="page"/g) || []).length, 1);
  assert.match(api, /href="\.\/api\.html" aria-current="page">API<\/a>/);
});

test("drives the switcher from the keyboard", async () => {
  for (const page of pages) {
    const html = await generated(page);
    for (const key of ["Escape", "ArrowDown", "ArrowUp", "Home", "End", "Tab"]) {
      assert.match(html, new RegExp(`"${key}"`), `${page}: ${key}`);
    }
    assert.match(html, /getElementById\("pkg-trigger"\)/, page);
  }
});

test("draws brand and links with tabler marks", async () => {
  for (const page of pages) {
    const html = await generated(page);
    assert.match(html, /<path d="M5 21c\.5 -4\.5 2\.5 -8 7 -10"\/>/, page);
    const nav = html.match(/<nav class="nav"[\s\S]*?<\/nav>/)[0];
    assert.match(
      nav,
      /<a class="nav__icon" href="https:\/\/github\.com\/tiliajs\/tilia" aria-label="Source on GitHub">/,
      page,
    );
    assert.doesNotMatch(nav, />GitHub</, page);
  }
});

test("credits the icon set wherever the site ships it", async () => {
  const notice = await readFile(path.join(root, "NOTICE.txt"), "utf8");
  assert.match(notice, /Tabler Icons/);
  assert.match(notice, /MIT License/);
  assert.match(notice, /Copyright \(c\) 2020-2026 Paweł Kuna/);
  assert.equal(await generated("notice.txt"), notice);

  for (const page of pages) {
    assert.match(await generated(page), /Tabler Icons \(MIT\)/, page);
  }
});

test("keeps project-specific switcher styling", async () => {
  const css = await readFile(path.join(root, "assets/style.css"), "utf8");

  assert.match(css, /\.pkg-switcher__menu\[data-open="true"\] \{[\s\S]*?display: block;/);
  assert.match(css, /\.pkg-option\[aria-selected="true"\][\s\S]*?background: var\(--accent-soft\);/);
  assert.match(css, /\.pkg-option\[aria-selected="false"\] \.check \{[\s\S]*?visibility: hidden;/);
  assert.match(css, /\.nav a\[aria-current="page"\] \{[\s\S]*?background: var\(--shade\);/);
  assert.match(css, /\.nav__icon svg \{[\s\S]*?width: 19px;/);
  assert.doesNotMatch(css, /\.package-mark|\.package-name/);

  assert.match(css, /body\.query \{[\s\S]*?--accent: #2c6d9e;/);
  assert.match(css, /body\.react \{[\s\S]*?--accent: #a4502a;[\s\S]*?--accent-deep: #7f3c20;/);
  assert.match(css, /body\.react \.tags span\.react \{[\s\S]*?color: var\(--accent-ink\);/);
});
