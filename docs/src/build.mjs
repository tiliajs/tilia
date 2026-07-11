import { readFile, readdir, mkdir, writeFile, copyFile, cp } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import YAML from "yaml";
import { parseApiEntry, parseBuildConfig, parseGuideChapter } from "./schema.mjs";
import { createPrismHighlighter, createMarkdown, renderBody } from "./markdown.mjs";
import { renderApiPage, renderDocsPage } from "./templates.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const contentDir = path.join(root, "content");
const configFile = path.join(contentDir, "tilia/config.yaml");
const sourceLabel = {
  api: "content/api/{{file}}",
  guide: "content/guide/{{file}}",
};
const parser = {
  parseApiEntry,
  parseGuideChapter,
};
export const configPathKeys = [
  "base",
  "pages.api.input.markdownDir",
  "pages.api.output.htmlFile",
  "pages.guide.input.markdownDir",
  "pages.guide.output.htmlFile",
  "pages.api.assets.copy[].from",
  "pages.api.assets.copy[].to",
  "pages.guide.assets.copy[].from",
  "pages.guide.assets.copy[].to",
];
const simplePathKeys = [
  ["base"],
  ["pages", "api", "input", "markdownDir"],
  ["pages", "api", "output", "htmlFile"],
  ["pages", "guide", "input", "markdownDir"],
  ["pages", "guide", "output", "htmlFile"],
];

function inject(template, values) {
  return template.replace(/\{\{([a-zA-Z0-9_]+)\}\}/g, (_, key) => {
    const value = values[key];
    if (value === undefined || value === null) return "";
    return String(value);
  });
}

function injectVars(template, vars) {
  return template.replace(/\{\{([a-zA-Z0-9_]+)\}\}/g, (all, key) => {
    if (Object.prototype.hasOwnProperty.call(vars, key)) {
      return String(vars[key]);
    }
    return all;
  });
}

function resolvePath(target, baseDir) {
  if (path.isAbsolute(target)) return target;
  return path.resolve(baseDir, target);
}

function resolveSimplePath(config, keys, baseDir) {
  let cursor = config;
  for (let i = 0; i < keys.length - 1; i++) {
    if (!object(cursor)) return;
    cursor = cursor[keys[i]];
  }
  if (!object(cursor)) return;
  const leaf = keys[keys.length - 1];
  if (typeof cursor[leaf] === "string") {
    cursor[leaf] = resolvePath(cursor[leaf], baseDir);
  }
}

function resolveCopyPaths(config, page, baseDir) {
  const copy = config?.pages?.[page]?.assets?.copy;
  if (!Array.isArray(copy)) return;
  for (const item of copy) {
    if (!object(item)) continue;
    if (typeof item.from === "string") item.from = resolvePath(item.from, baseDir);
    if (typeof item.to === "string") item.to = resolvePath(item.to, baseDir);
  }
}

function resolveConfigPaths(config, baseDir) {
  for (const keys of simplePathKeys) resolveSimplePath(config, keys, baseDir);
  resolveCopyPaths(config, "api", baseDir);
  resolveCopyPaths(config, "guide", baseDir);
  return config;
}

async function findConfigFiles(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await findConfigFiles(file)));
      continue;
    }
    if (entry.isFile() && entry.name === "config.yaml") {
      files.push(file);
    }
  }
  return files.sort();
}

export async function findConfigs() {
  return findConfigFiles(contentDir);
}

function object(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function merge(base, top) {
  if (top === undefined) return base;
  if (Array.isArray(top)) return top;
  if (object(base) && object(top)) {
    const out = { ...base };
    for (const key of Object.keys(top)) {
      out[key] = merge(base[key], top[key]);
    }
    return out;
  }
  return top;
}

function applyVars(value, vars) {
  if (typeof value === "string") {
    return injectVars(value, vars);
  }
  if (Array.isArray(value)) {
    return value.map((item) => applyVars(item, vars));
  }
  if (object(value)) {
    const out = {};
    for (const key of Object.keys(value)) {
      out[key] = applyVars(value[key], vars);
    }
    return out;
  }
  return value;
}

function sourcePath(pattern, file) {
  return inject(pattern, { file });
}

function parserFor(name, fallback) {
  if (name && parser[name]) return parser[name];
  return fallback;
}

function matches(file, glob) {
  if (!glob || glob === "*.md") return file.endsWith(".md");
  return file.endsWith(".md");
}

async function loadMergedConfig(target, seen) {
  const file = path.resolve(target);
  if (seen.has(file)) {
    throw new Error(`${file}: circular base chain`);
  }
  seen.add(file);

  const raw = await readFile(file, "utf8");
  const local = resolveConfigPaths(YAML.parse(raw), path.dirname(file));
  if (!object(local)) {
    seen.delete(file);
    throw new Error(`${file}: config must be an object`);
  }

  let config = local;
  if (typeof local.base === "string" && local.base.length > 0) {
    const baseConfig = await loadMergedConfig(local.base, seen);
    config = merge(baseConfig, local);
  }
  seen.delete(file);
  return config;
}

export async function loadConfig(target = configFile, seen = new Set()) {
  const file = path.resolve(target);
  const config = await loadMergedConfig(file, seen);
  const parsed = parseBuildConfig(file, config);
  const resolved = applyVars(parsed, parsed.var);
  return resolved;
}

function copyPlan(config) {
  const all = [];
  const pages = config?.pages || {};
  for (const key of Object.keys(pages)) {
    const copy = pages[key]?.assets?.copy || [];
    for (const entry of copy) all.push(entry);
  }
  const uniq = new Map();
  for (const entry of all) {
    const key = `${entry.from}=>${entry.to}|${entry.recursive ? "r" : "f"}`;
    if (!uniq.has(key)) uniq.set(key, entry);
  }
  return [...uniq.values()];
}

async function copyAssetsForConfig(config, target) {
  const baseDir = path.dirname(path.resolve(target));
  const jobs = copyPlan(config);
  for (const job of jobs) {
    const from = resolvePath(job.from, baseDir);
    const to = resolvePath(job.to, baseDir);
    await mkdir(path.dirname(to), { recursive: true });
    if (job.recursive) {
      await cp(from, to, { recursive: true });
      continue;
    }
    await copyFile(from, to);
  }
  console.log(`[${config.var.project}] Copied assets to dist/`);
}

export async function copyAssets(config = null, target = configFile) {
  if (config) {
    await copyAssetsForConfig(config, target);
    return;
  }
  const configs = await findConfigs();
  for (const file of configs) {
    const loaded = await loadConfig(file);
    await copyAssetsForConfig(loaded, file);
  }
}

async function collect(dir, glob = "*.md") {
  const files = (await readdir(dir)).filter((f) => matches(f, glob)).sort();
  const out = [];
  for (const file of files) {
    const raw = await readFile(path.join(dir, file), "utf8");
    out.push({ file, raw });
  }
  return out;
}

function collectApiEntries(files, errors, pattern, parserName) {
  const parse = parserFor(parserName, parseApiEntry);
  const entries = [];
  for (const { file, raw } of files) {
    const fileLabel = sourcePath(pattern, file);
    try {
      const entry = parse(fileLabel, raw);
      const expectedSlug = file.replace(/\.md$/, "");
      if (entry.slug !== expectedSlug) {
        errors.push(`${fileLabel}: slug "${entry.slug}" must equal filename "${expectedSlug}"`);
      }
      entries.push({ ...entry, file });
    } catch (err) {
      errors.push(err.message);
    }
  }
  return entries;
}

function collectGuideChapters(files, errors, pattern, parserName) {
  const parse = parserFor(parserName, parseGuideChapter);
  const chapters = [];
  for (const { file, raw } of files) {
    const fileLabel = sourcePath(pattern, file);
    try {
      const chapter = parse(fileLabel, raw);
      const m = file.match(/^(\d+)-(.+)\.md$/);
      if (!m) {
        errors.push(`${fileLabel}: filename must match "NN-slug.md"`);
      } else {
        const [, prefix, slugPart] = m;
        if (chapter.slug !== slugPart) {
          errors.push(`${fileLabel}: slug "${chapter.slug}" must equal filename slug "${slugPart}"`);
        }
        if (chapter.sort !== Number(prefix)) {
          errors.push(`${fileLabel}: sort ${chapter.sort} must equal filename prefix ${Number(prefix)}`);
        }
      }
      chapters.push({ ...chapter, file });
    } catch (err) {
      errors.push(err.message);
    }
  }
  return chapters;
}

export function crossValidate(entries, chapters, errors, labels = sourceLabel) {
  const slugs = new Set();
  for (const e of entries) {
    const fileLabel = sourcePath(labels.api, e.file);
    if (slugs.has(e.slug)) errors.push(`${fileLabel}: duplicate slug "${e.slug}"`);
    slugs.add(e.slug);
  }
  const names = new Set();
  for (const e of entries) {
    const key = `${e.module}:${e.name}`;
    const fileLabel = sourcePath(labels.api, e.file);
    if (names.has(key)) errors.push(`${fileLabel}: duplicate name "${e.name}" in module "${e.module}"`);
    names.add(key);
  }
  const chapterSlugs = new Set();
  for (const c of chapters) {
    const fileLabel = sourcePath(labels.guide, c.file);
    if (chapterSlugs.has(c.slug)) errors.push(`${fileLabel}: duplicate slug "${c.slug}"`);
    chapterSlugs.add(c.slug);
  }
  const chapterSorts = new Set();
  for (const c of chapters) {
    const fileLabel = sourcePath(labels.guide, c.file);
    if (chapterSorts.has(c.sort)) errors.push(`${fileLabel}: duplicate sort ${c.sort}`);
    chapterSorts.add(c.sort);
  }
  for (const c of chapters) {
    const fileLabel = sourcePath(labels.guide, c.file);
    for (const ref of c.refs) {
      if (!slugs.has(ref)) {
        errors.push(`${fileLabel}: refs entry "${ref}" does not match any API slug`);
      }
    }
  }
}

function renderBodies(md, entries, chapters, errors, labels = sourceLabel) {
  for (const e of entries) {
    const fileLabel = sourcePath(labels.api, e.file);
    try {
      e.bodyHtml = renderBody(md, fileLabel, e.body, {
        allowHeadings: false,
        page: "api",
      });
    } catch (err) {
      errors.push(err.message);
    }
  }
  for (const c of chapters) {
    const fileLabel = sourcePath(labels.guide, c.file);
    try {
      c.bodyHtml = renderBody(md, fileLabel, c.body, {
        allowHeadings: true,
        page: "docs",
      });
    } catch (err) {
      errors.push(err.message);
    }
  }
}

async function runConfigBuild(configPath, highlighter, md) {
  const configDir = path.dirname(configPath);
  const config = await loadConfig(configPath);
  const pages = config.pages || {};
  const apiPage = pages.api || {};
  const guidePage = pages.guide || {};
  const apiInput = apiPage.input || {};
  const guideInput = guidePage.input || {};
  const apiOutput = apiPage.output || {};
  const guideOutput = guidePage.output || {};
  const labels = {
    api: apiInput.sourceLabel || sourceLabel.api,
    guide: guideInput.sourceLabel || sourceLabel.guide,
  };

  const apiDir = resolvePath(apiInput.markdownDir || "api", configDir);
  const guideDir = resolvePath(guideInput.markdownDir || "guide", configDir);
  const apiFile = resolvePath(apiOutput.htmlFile || "../../dist/api.html", configDir);
  const docsFile = resolvePath(guideOutput.htmlFile || "../../dist/docs.html", configDir);

  const errors = [];
  const [apiFiles, guideFiles] = await Promise.all([
    collect(apiDir, apiInput.glob),
    collect(guideDir, guideInput.glob),
  ]);
  const entries = collectApiEntries(apiFiles, errors, labels.api, apiInput.parser);
  const chapters = collectGuideChapters(guideFiles, errors, labels.guide, guideInput.parser);
  crossValidate(entries, chapters, errors, labels);

  renderBodies(md, entries, chapters, errors, labels);

  if (errors.length > 0) {
    console.error(`Build failed for ${configPath} with ${errors.length} error(s):\n`);
    for (const e of errors) console.error(`  - ${e}`);
    return { ok: false, entries: 0, chapters: 0, bytes: 0 };
  }

  const apiHtml = renderApiPage({ entries, highlighter, config });
  const docsHtml = renderDocsPage({ chapters, config });

  await mkdir(path.dirname(apiFile), { recursive: true });
  await mkdir(path.dirname(docsFile), { recursive: true });
  await writeFile(apiFile, apiHtml);
  await writeFile(docsFile, docsHtml);
  await copyAssetsForConfig(config, configPath);

  const bytes = Buffer.byteLength(apiHtml) + Buffer.byteLength(docsHtml);
  console.log(
    `[${config.var.project}] Built ${entries.length} API entries, ${chapters.length} guide chapters — ${bytes} bytes written to dist/`
  );
  return { ok: true, entries: entries.length, chapters: chapters.length, bytes };
}

export async function runBuild() {
  const configs = await findConfigs();
  if (configs.length === 0) {
    console.error("Build failed: no config.yaml files found in content/");
    return { ok: false };
  }

  const highlighter = await createPrismHighlighter();
  const md = createMarkdown(highlighter);

  let ok = true;
  let totalEntries = 0;
  let totalChapters = 0;
  let totalBytes = 0;

  for (const file of configs) {
    try {
      const result = await runConfigBuild(file, highlighter, md);
      if (!result.ok) {
        ok = false;
        continue;
      }
      totalEntries += result.entries;
      totalChapters += result.chapters;
      totalBytes += result.bytes;
    } catch (err) {
      ok = false;
      console.error(`Build failed for ${file}:\n`);
      console.error(`  - ${err.message}`);
    }
  }

  if (!ok) return { ok: false };
  console.log(
    `Built ${configs.length} project config(s) — ${totalEntries} API entries, ${totalChapters} guide chapters, ${totalBytes} bytes`
  );
  return { ok: true };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const { ok } = await runBuild();
  if (!ok) process.exit(1);
}
