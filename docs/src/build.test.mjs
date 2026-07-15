import test from "node:test";
import assert from "node:assert/strict";
import os from "node:os";
import path from "node:path";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { crossValidate, findConfigs, loadConfig } from "./build.mjs";
import { renderDocsPage } from "./templates.mjs";

function entry(file, module, name, slug) {
  return { file, module, name, slug };
}

test("allows duplicate names across modules", () => {
  const errors = [];
  const entries = [
    entry("make.md", "core", "make", "make"),
    entry("react-make.md", "react", "make", "react-make"),
  ];

  crossValidate(entries, [], errors);

  assert.equal(errors.length, 0);
});

test("reports duplicate names in same module", () => {
  const errors = [];
  const entries = [
    entry("make.md", "core", "make", "make"),
    entry("make-2.md", "core", "make", "make-2"),
  ];

  crossValidate(entries, [], errors);

  assert.deepEqual(errors, ['content/api/make-2.md: duplicate name "make" in module "core"']);
});

test("loads tilia config from content folder", async () => {
  const config = await loadConfig();

  assert.equal(config.var.project, "tilia");
  assert.equal(config.pages.api.input.markdownDir, path.resolve(process.cwd(), "content/tilia/api"));
  assert.equal(config.pages.guide.input.markdownDir, path.resolve(process.cwd(), "content/tilia/guide"));
  assert.equal(config.pages.api.output, path.resolve(process.cwd(), "dist/tilia/api.html"));
});

test("rejects invalid config format", async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), "tilia-config-"));
  try {
    const file = path.join(dir, "config.yaml");
    await writeFile(file, "pages: {}\n");
    await assert.rejects(loadConfig(file), /var|shared|literals/);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("resolves variables before paths", async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), "tilia-config-"));
  try {
    const file = path.join(dir, "config.yaml");
    const base = path.join(dir, "base.yaml");
    const assets = path.join(dir, "assets");
    const dist = path.join(dir, "dist");
    const shared = path.join(dir, "shared");
    await writeFile(
      base,
      [
        `base: "${path.resolve(process.cwd(), "content/base-config.yaml")}"`,
        "var:",
        `  shared: "${shared}"`,
      ].join("\n"),
    );
    await writeFile(
      file,
      [
        `base: "${base}"`,
        "var:",
        "  project: example",
        `  assets: "${assets}"`,
        `  dist: "${dist}"`,
        "pages:",
        "  api:",
        "    output: '{{dist}}/api.html'",
        "    assets:",
        "      copy:",
        "        - from: '{{assets}}/style.css'",
        "          to: '{{dist}}/style.css'",
        "        - from: '{{shared}}/fonts'",
        "          to: '{{dist}}/fonts'",
        "          recursive: true",
      ].join("\n"),
    );

    const config = await loadConfig(file);
    assert.equal(config.pages.api.assets.copy[0].from, path.join(assets, "style.css"));
    assert.equal(config.pages.api.assets.copy[0].to, path.join(dist, "style.css"));
    assert.equal(config.pages.api.assets.copy[1].from, path.join(shared, "fonts"));
    assert.equal(config.pages.api.output, path.join(dist, "api.html"));
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("loads query config via base", async () => {
  const file = path.resolve(process.cwd(), "content/query/config.yaml");
  const config = await loadConfig(file);

  assert.equal(config.var.project, "query");
  assert.equal(config.pages.api.input.markdownDir, path.resolve(process.cwd(), "content/query/api"));
  assert.equal(config.pages.guide.input.markdownDir, path.resolve(process.cwd(), "content/query/guide"));
  assert.equal(config.pages.api.input.glob, "*.md");
  assert.equal(config.pages.api.output, path.resolve(process.cwd(), "dist/query/api.html"));
});

test("deep merges literals over base", async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), "tilia-config-"));
  try {
    const base = path.resolve(process.cwd(), "content/tilia/config.yaml");
    const file = path.join(dir, "config.yaml");
    await writeFile(
      file,
      [
        `base: "${base}"`,
        "var:",
        "  project: query",
        "shared:",
        "  literals:",
        "    moduleLabelCore: Query",
      ].join("\n")
    );

    const config = await loadConfig(file);
    assert.equal(config.shared.literals.moduleLabelCore, "Query");
    assert.equal(config.shared.literals.moduleLabelReact, "React");
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("finds all project configs in content", async () => {
  const files = await findConfigs();
  const rel = files.map((file) => path.relative(process.cwd(), file));
  assert(rel.includes("content/tilia/config.yaml"));
  assert(rel.includes("content/query/config.yaml"));
});

test("resolves child file paths before merge", async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), "tilia-config-"));
  try {
    const base = path.resolve(process.cwd(), "content/tilia/config.yaml");
    const file = path.join(dir, "config.yaml");
    await writeFile(
      file,
      [
        `base: "${base}"`,
        "var:",
        "  project: query",
        "pages:",
        "  api:",
        "    output: ./out/{{project}}/api.html",
      ].join("\n")
    );
    const config = await loadConfig(file);
    assert.equal(config.pages.api.output, path.resolve(dir, "out/query/api.html"));
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("deep merges nested page template keys", async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), "tilia-config-"));
  try {
    const base = path.resolve(process.cwd(), "content/tilia/config.yaml");
    const file = path.join(dir, "config.yaml");
    await writeFile(
      file,
      [
        `base: "${base}"`,
        "var:",
        "  project: query",
        "pages:",
        "  guide:",
        "    templates:",
        "      pageMain: <div class=\"docs-head\">Query docs</div>",
      ].join("\n")
    );
    const config = await loadConfig(file);

    assert.equal(config.pages.guide.templates.pageMain, '<div class="docs-head">Query docs</div>');
    assert.equal(config.pages.guide.templates.tocItem, '<li><a href="#{{slug}}">{{title}}</a></li>');
    assert.equal(config.pages.guide.templates.chapter.includes("{{bodyHtml}}"), true);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("renders guide body when pageMain omits slots", async () => {
  const config = await loadConfig(path.resolve(process.cwd(), "content/query/config.yaml"));
  const html = renderDocsPage({
    config,
    chapters: [
      {
        sort: 1,
        slug: "remote-data",
        title: "Remote Data",
        refs: ["make"],
        bodyHtml: "<p>Body</p>",
      },
    ],
  });

  assert.match(html, /<section class="chapter" id="remote-data">/);
  assert.match(html, /<li><a href="#remote-data">Remote Data<\/a><\/li>/);
  assert.match(html, /Reference: <a href="\.\/api\.html#make">make<\/a>/);
});
