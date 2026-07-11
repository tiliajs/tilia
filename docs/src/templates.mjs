import { highlightCode, toggleButton } from "./markdown.mjs";

const TOKEN = /\{\{([a-zA-Z0-9_]+)\}\}/g;
const MODULE_ORDER = ["core", "react"];

function inject(template, values) {
  return template.replace(TOKEN, (_, key) => {
    const value = values[key];
    if (value === undefined || value === null) return "";
    return String(value);
  });
}

function literalsFromConfig(config) {
  return config.shared.literals;
}

function pageFromConfig(config, page) {
  const source = config?.pages?.[page];
  if (!source) throw new Error(`missing page config: ${page}`);
  return source;
}

function hasSlot(template, key) {
  return template.includes(`{{${key}}}`);
}

function apiIndex(index) {
  return `<nav class="api-index" aria-label="API index">
${index}
  </nav>`;
}

function apiEntries(articles) {
  return `<div class="api-entries">
${articles}
  </div>`;
}

function apiLayout(index, articles) {
  return `<div class="wrap api-layout">
  ${apiIndex(index)}
  ${apiEntries(articles)}
</div>`;
}

function apiMain(template, index, articles) {
  const main = inject(template, { index, articles });
  const indexSlot = hasSlot(template, "index");
  const articlesSlot = hasSlot(template, "articles");
  if (indexSlot && articlesSlot) return main;
  if (!indexSlot && !articlesSlot) return `${main}\n\n${apiLayout(index, articles)}`;
  if (!indexSlot) return `${main}\n\n${apiIndex(index)}`;
  return `${main}\n\n${apiEntries(articles)}`;
}

function guideToc(toc) {
  return `<nav class="toc" aria-label="Chapters">
    <p class="k idx-group">Read in order</p>
    <ol>
${toc}
    </ol>
  </nav>`;
}

function guideChapters(chapters) {
  return `<div class="chapters">
${chapters}
  </div>`;
}

function guideLayout(toc, chapters) {
  return `<div class="wrap docs-layout">
  ${guideToc(toc)}
  ${guideChapters(chapters)}
</div>`;
}

function guideMain(template, toc, chapters) {
  const main = inject(template, { toc, chapters });
  const tocSlot = hasSlot(template, "toc");
  const chaptersSlot = hasSlot(template, "chapters");
  if (tocSlot && chaptersSlot) return main;
  if (!tocSlot && !chaptersSlot) return `${main}\n\n${guideLayout(toc, chapters)}`;
  if (!tocSlot) return `${main}\n\n${guideToc(toc)}`;
  return `${main}\n\n${guideChapters(chapters)}`;
}

function moduleLabel(literals) {
  return {
    core: literals.moduleLabelCore,
    react: literals.moduleLabelReact,
  };
}

function header(active, literals) {
  return inject(literals.header, {
    wordmarkSvg: literals.wordmarkSvg,
    docsCurrentAttr: active === "docs" ? ' aria-current="page"' : "",
    apiCurrentAttr: active === "api" ? ' aria-current="page"' : "",
  });
}

function footer(literals) {
  return inject(literals.footer, {});
}

export function shell({
  title,
  description,
  active,
  main,
  scripts = [],
  includePrePaint = false,
  includeToggleScript = false,
  includeSkip = false,
  htmlAttrs = 'lang="en"',
  mainAttrs = "",
  literals,
}) {
  const bundledScripts = includeToggleScript ? [literals.toggleListenerScript, ...scripts] : scripts;
  const allScripts = bundledScripts.map((code) => `<script>${code}</script>`).join("\n");
  const prePaint = includePrePaint ? `<script>${literals.prePaintScript}</script>` : "";
  const skip = includeSkip ? '<a class="skip" href="#content">Skip to content</a>' : "";
  return inject(literals.shell, {
    htmlAttrs,
    description,
    title,
    faviconUrl: literals.faviconUrl,
    prePaint,
    skip,
    header: header(active, literals),
    mainAttrs,
    main,
    footer: footer(literals),
    scripts: allScripts,
  });
}

function renderSignaturePair(highlighter, ts, res, template) {
  const tsHtml = highlightCode(highlighter, ts, "typescript").replace(
    '<pre class="language-typescript">',
    '<pre class="sig language-typescript">'
  );
  const resHtml = highlightCode(highlighter, res, "rescript").replace(
    '<pre class="language-rescript">',
    '<pre class="sig language-rescript">'
  );
  return inject(template, {
    toggleButton,
    tsHtml,
    resHtml,
  });
}

function indexLabel(entry) {
  const m = entry.signature.ts.match(/^(?:function\s+\w+|collection\.\w+)(?:<[^>]+>)?\(([^)]*)\)/);
  if (!m) return entry.name;
  const raw = m[1].trim();
  if (raw === "") return `${entry.name}()`;
  const args = raw
    .replace(/<[^<>]*>/g, "")
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean)
    .map((part) => {
      const [name] = part.split(":");
      return name.trim();
    })
    .join(", ");
  return `${entry.name}(${args})`;
}

export function renderApiPage({ entries, highlighter, config }) {
  return renderApiPageFromConfig({ entries, highlighter, config });
}

function renderApiPageFromConfig({ entries, highlighter, config }) {
  const literals = literalsFromConfig(config);
  const page = pageFromConfig(config, "api");
  const labels = moduleLabel(literals);

  const groups = MODULE_ORDER.map((mod) => ({
    mod,
    entries: entries.filter((e) => e.module === mod).sort((a, b) => a.sort - b.sort),
  })).filter((g) => g.entries.length > 0);

  const index = groups
    .map((g) =>
      inject(page.templates.indexGroup, {
        moduleLabel: labels[g.mod],
        indexItems: g.entries
          .map((e) =>
            inject(page.templates.indexItem, {
              slug: e.slug,
              indexLabel: indexLabel(e),
            })
          )
          .join("\n"),
      })
    )
    .join("\n");

  const articles = groups
    .map((g) =>
      g.entries
        .map((e) =>
          renderApiEntry(e, highlighter, {
            templates: page.templates,
            labels,
          })
        )
        .join("\n")
    )
    .join("\n");

  const main = apiMain(page.templates.pageMain, index, articles);
  const scripts = (page.document.scripts || []).map((code) => inject(code, literals));

  return shell({
    title: page.document.title,
    description: page.document.description,
    active: page.document.activeNav,
    main,
    includePrePaint: page.document.includePrePaint,
    includeToggleScript: page.document.includeToggleScript,
    includeSkip: page.document.includeSkip,
    htmlAttrs: page.document.htmlAttrs,
    mainAttrs: page.document.mainAttrs,
    scripts,
    literals,
  });
}

function renderApiEntry(entry, highlighter, context) {
  const { labels, templates } = context;
  const tags = [entry.module, ...entry.tags]
    .map((t, i) => `<span${i === 0 ? ` class="${entry.module}"` : ""}>${i === 0 ? labels[entry.module] : t}</span>`)
    .join("");
  const sig = renderSignaturePair(
    highlighter,
    entry.signature.ts,
    entry.signature.res,
    templates.signaturePair
  );
  return inject(templates.entry, {
    slug: entry.slug,
    indexLabel: indexLabel(entry),
    tags,
    since: entry.since,
    summary: entry.summary,
    signaturePair: sig,
    bodyHtml: entry.bodyHtml,
  });
}

export function renderDocsPage({ chapters, config }) {
  const literals = literalsFromConfig(config);
  const page = pageFromConfig(config, "guide");
  const sorted = [...chapters].sort((a, b) => a.sort - b.sort);
  const toc = sorted
    .map((c) =>
      inject(page.templates.tocItem, {
        slug: c.slug,
        title: c.title,
      })
    )
    .join("\n");
  const body = sorted.map((c, i) => renderChapter(c, i, page.templates)).join("\n");
  const main = guideMain(page.templates.pageMain, toc, body);
  const scripts = (page.document.scripts || []).map((code) => inject(code, literals));

  return shell({
    title: page.document.title,
    description: page.document.description,
    active: page.document.activeNav,
    main,
    includePrePaint: page.document.includePrePaint,
    includeToggleScript: page.document.includeToggleScript,
    includeSkip: page.document.includeSkip,
    htmlAttrs: page.document.htmlAttrs,
    mainAttrs: page.document.mainAttrs,
    scripts,
    literals,
  });
}

function renderChapter(chapter, index, templates) {
  const refs =
    chapter.refs.length > 0
      ? inject(templates.refs, {
        refs: chapter.refs.map((slug) => `<a href="./api.html#${slug}">${slug}</a>`).join(", "),
      })
      : "";
  return inject(templates.chapter, {
    slug: chapter.slug,
    chapterNo: String(index + 1).padStart(2, "0"),
    title: chapter.title,
    bodyHtml: chapter.bodyHtml,
    refsBlock: refs,
  });
}
