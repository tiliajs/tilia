import * as S from "sury";
import matter from "gray-matter";

const slugPattern = /^[a-z0-9-]+$/;

const apiEntrySchema = S.schema({
  name: S.string,
  slug: S.string.with(S.pattern, slugPattern),
  kind: S.union(["function", "type", "hook"]),
  module: S.union(["core", "react"]),
  since: S.string,
  sort: S.int32,
  summary: S.string,
  signature: S.schema({
    ts: S.min(S.string, 1),
    res: S.min(S.string, 1),
  }),
  tags: S.optional(S.array(S.string), []),
});

const guideChapterSchema = S.schema({
  title: S.string,
  slug: S.string.with(S.pattern, slugPattern),
  sort: S.int32,
  refs: S.optional(S.array(S.string), []),
});

const copyAssetSchema = S.schema({
  from: S.string,
  to: S.string,
  recursive: S.optional(S.boolean, false),
});

const pageInputSchema = S.schema({
  markdownDir: S.string,
  glob: S.string,
  parser: S.union(["parseApiEntry", "parseGuideChapter"]),
  sourceLabel: S.string,
});

const pageOutputSchema = S.schema({
  htmlFile: S.string,
});

const pageDocumentSchema = S.schema({
  title: S.string,
  description: S.string,
  activeNav: S.union(["api", "docs"]),
  htmlAttrs: S.string,
  includePrePaint: S.boolean,
  includeToggleScript: S.boolean,
  includeSkip: S.boolean,
  mainAttrs: S.string,
  scripts: S.optional(S.array(S.string), []),
});

const pageAssetsSchema = S.schema({
  copy: S.array(copyAssetSchema),
});

const apiTemplatesSchema = S.schema({
  indexGroup: S.string,
  indexItem: S.string,
  signaturePair: S.string,
  entry: S.string,
  pageMain: S.string,
});

const guideTemplatesSchema = S.schema({
  tocItem: S.string,
  refs: S.string,
  chapter: S.string,
  pageMain: S.string,
});

const pageApiSchema = S.schema({
  input: pageInputSchema,
  output: pageOutputSchema,
  templates: apiTemplatesSchema,
  document: pageDocumentSchema,
  assets: pageAssetsSchema,
});

const pageGuideSchema = S.schema({
  input: pageInputSchema,
  output: pageOutputSchema,
  templates: guideTemplatesSchema,
  document: pageDocumentSchema,
  assets: pageAssetsSchema,
});

const buildConfigSchema = S.schema({
  base: S.optional(S.string),
  var: S.schema({
    project: S.string,
  }),
  shared: S.schema({
    literals: S.schema({
      wordmarkSvg: S.string,
      faviconUrl: S.string,
      prePaintScript: S.string,
      toggleListenerScript: S.string,
      docsScrollSpyScript: S.string,
      viewSwitchScript: S.optional(S.string, ""),
      header: S.string,
      footer: S.string,
      shell: S.string,
      moduleLabelCore: S.string,
      moduleLabelReact: S.string,
    }),
  }),
  pages: S.schema({
    api: pageApiSchema,
    guide: pageGuideSchema,
  }),
});

function parseEntry(file, raw, schema) {
  const { data, content } = matter(raw);
  try {
    const frontmatter = S.parser(schema)(data);
    return { ...frontmatter, body: content };
  } catch (err) {
    throw new Error(`${file}: ${err.message}`);
  }
}

export function parseApiEntry(file, raw) {
  return parseEntry(file, raw, apiEntrySchema);
}

export function parseGuideChapter(file, raw) {
  return parseEntry(file, raw, guideChapterSchema);
}

export function parseBuildConfig(file, data) {
  try {
    return S.parser(buildConfigSchema)(data);
  } catch (err) {
    throw new Error(`${file}: ${err.message}`);
  }
}
