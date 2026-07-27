# @tilia/react as its own package page — implementation brief

Working document. Delete once the work has landed.

## Prompt for a new session

> Read `docs/plan-react-package.md` in `/Users/anna/git/tilia` and execute it end to end.
> Work test-first: update `docs/src/site.test.mjs` for each item before changing the content,
> and run `cd docs && pnpm test` after each item — `output.test.mjs` walks every generated
> link and anchor, so it is the gate that proves the URL moves are complete.
> Keep the épure house style: single-word camelCase names, no comments that restate the code,
> and prose in the voice of the surrounding chapters.

## The decisions already taken

- `@tilia/react` becomes the third package in the switcher, with **Home + API only** — no Guide.
- The React narrative (today's guide chapter 10) becomes the react home, which also gains
  **React Native examples**: tilia works with RN unchanged, and the home is the place to show it.
- Guide chapter 10 **stays in the tilia guide**, renamed and slimmed to a framework-agnostic
  "Views are observers". No renumbering: chapter 9's closing handoff and chapter 12's recap
  both survive untouched.
- The tilia home hero keeps its React snippet but **names the package**.
- Adapters get the autumn accent.

## The season colour system

- green / spring / foundation — `tilia`
- blue / summer / consolidation — `@tilia/query`
- russet / autumn / presentation — `@tilia/react`, and every adapter after it

Verified against the family's own contrast register (green accent 4.93:1 vs `--btn-label`,
ink 6.88:1 on paper; blue 5.35 / 6.78):

```css
/* ============================================================
   @tilia/react — autumn accent (body.react)
   The seasons name the layer: spring green is the foundation,
   summer blue the consolidation, autumn russet the presentation.
   Every view adapter shares this skin. Redder than --honey, which
   stays the warm decorative second.
   ============================================================ */
body.react {
  --accent: #a4502a; /* 5.4:1 vs --btn-label — AA */
  --accent-ink: #8a3f22; /* 6.9:1 on paper */
  --accent-soft: #f2e5dc;
  --accent-deep: #7f3c20;
}
body.react .tags span.react {
  color: var(--accent-ink);
  border-color: var(--accent);
}
```

The last rule matters because `.tags span.react` is honey today
([docs/assets/style.css](docs/assets/style.css) around line 1097); on a russet page the chip
should carry the page's own accent. The switcher trigger, the selected menu option and the
nav pill all read `--accent-ink` / `--accent-soft`, so they follow automatically.

## Machinery you will reuse

The header is declared once, in [docs/content/tilia/config.yaml](docs/content/tilia/config.yaml),
and inherited by every package (minidoc inherits formulas, not values). A package is:

- one data row in `docs/content/packages/` — `pkg`, `scopedName`, `tagline`, `href`;
- three vars in its own config — `rootHref`, `currentPkg`, `currentName`;
- `aria-selected` comes from the `pkgSelected` value var through the `same` transform
  registered in [docs/src/build.mjs](docs/src/build.mjs), so no per-package markup.

Menu order follows filename order, so `030-react.md` lands third.

## Work items

### 1. Autumn accent

Add the `body.react` block above to [docs/assets/style.css](docs/assets/style.css), next to the
existing `body.query` block at the end of the file.

### 2. Package data row

`docs/content/packages/030-react.md`:

```yaml
---
pkg: react
scopedName: "@tilia/react"
tagline: Views that observe the domain
href: react/index.html
---
```

### 3. Per-package nav links

The shared header hardcodes three text links. Extract them so react can carry two.
In [docs/content/tilia/config.yaml](docs/content/tilia/config.yaml), add a var:

```yaml
  navLinks: |-
    <a href="./index.html"{{homeCurrentAttr}}>Home</a>
          <a href="./guide.html"{{guideCurrentAttr}}>Guide</a>
          <a href="./api.html"{{apiCurrentAttr}}>API</a>
```

and replace those three lines inside the `header` var with `{{navLinks}}`. The react config
overrides it with Home and API only. `homeCurrentAttr` / `apiCurrentAttr` keep working as
attribute slots.

### 4. The react config

`docs/content/react/config.yaml`, modelled on
[docs/content/query/config.yaml](docs/content/query/config.yaml):

```yaml
base: ../tilia/config.yaml
var:
  output: ../../dist/react
  assets: ../../assets
  model: ../../../react/llms.txt
  rootHref: "../"
  currentPkg: react
  currentName: "@tilia/react"
  navLinks: |-
    <a href="./index.html"{{homeCurrentAttr}}>Home</a>
          <a href="./api.html"{{apiCurrentAttr}}>API</a>
  shell: ...      # <body class="react">, ../style.css, ./llms.txt alternate
  footer: ...     # npm cell -> @tilia/react
  homeMain:
    file: home/index.html
  reactIndex:
    dir: api
    each: '        <a href="#{{slug}}">{{label}}</a>'
  reactEntries:
    dir: api
    transform: apiMd
    each: ...     # <span class="react">React</span> in the tags line
  apiMain: ...    # one "React" index group
build:
  - output: "{{output}}/index.html"   # + the hero ts|res toggle script, copied from query
  - output: "{{output}}/api.html"
  - output: "{{output}}/llms.txt"
```

Skip the `style.css` and `fonts` copies: the shell links `../style.css` at the dist root.
(Query copies them into its own subtree redundantly — do not repeat that.) The header's
licence comment resolves through `{{rootHref}}` to `../notice.txt`, which already exists.

### 5. Move the API entries

`docs/content/tilia/api/react/*.md` → `docs/content/react/api/`, renumbered 010–050, keeping
every slug: `leaf`, `use-tilia`, `use-computed`, `react-make`, `tilia-react-type`.
Keep `module: react` — the tag chip class depends on it.

Link fixes inside the moved files:

- `guide.html#tilia-in-react` (in `140-leaf.md`, `150-use-tilia.md`, `160-use-computed.md`)
  becomes `index.html` — the narrative is now the react home.
- In `react-make`, the two core links `api.html#tilia-type` and `api.html#make` become
  `../api.html#…`.
- Intra-react links (`api.html#leaf`, `#use-tilia`, `#use-computed`, `#react-make`) stay as they are.

And in the other direction: `docs/content/tilia/api/core/250-tilia-type.md` links
`api.html#react-make`, which becomes `react/api.html#react-make`.

Then drop `reactIndex`, `reactEntries` and the `React` index heading from the tilia
`apiMain` in [docs/content/tilia/config.yaml](docs/content/tilia/config.yaml).

### 6. The react home

`docs/content/react/home/index.html`, a body fragment like the other two homes
(no doctype, no header, no script — `site.test.mjs` asserts this).

Shape: short hero with a code figure (`id="hero-code"`, the ts|res langswitch), then the
narrative lifted from today's chapter 10 — `leaf` first as the favoured way, `useTilia` as the
retrofit, `useComputed` for the answer — then a **React Native** section showing the same
component in RN (`View` / `Text`), making the point that the adapter is the same because the
reactivity is the same. Close with a line back to the tilia guide for readers who arrived here
first, the way chapter 12 hands off to query.

### 7. Slim and rename guide chapter 10

`docs/content/tilia/guide/10-tilia-in-react.md` → `10-views-are-observers.md`:

```yaml
title: Views are observers
slug: views-are-observers
sort: 10
refs: []          # critical: the old [leaf, use-tilia, use-computed] would render
chapter: "10"     # ./api.html#leaf, which no longer exists on the tilia api page
```

Keep the opening (the suite stays green, no logic in views), the "views are observers" idea,
the story callout, and the closing question — *what happens when someone gets it wrong?* — so
chapter 11 still follows. Replace the three API sections with a short handoff naming
`@tilia/react`, linking `./react/index.html`, and noting React Native. Chapter 9's closing
line, "it is time to give the scheduler a face", still lands.

### 8. Chapter 12

In [docs/content/tilia/guide/12-onward.md](docs/content/tilia/guide/12-onward.md), add a
paragraph for `@tilia/react` beside the `@tilia/query` one in "Where to go from here",
mentioning React Native.

### 9. Redirects — three places, all of them

- [docs/src/redirects.mjs](docs/src/redirects.mjs): in `api`, `#leaf`, `#usetilia`,
  `#useTilia`, `#usecomputed`, `#useComputed` now point at `./react/api.html#…`; in `guide`,
  `#react` and `#react-integration` point at `./react/index.html`.
- The guide's inline hash router in [docs/content/tilia/config.yaml](docs/content/tilia/config.yaml)
  carries the same map — apply the same edits, and add
  `"#tilia-in-react": "./react/index.html"` for the slug that just disappeared.
- New: the `api.html` build entry needs its own hash router (copy the guide's pattern) mapping
  `#leaf`, `#use-tilia`, `#use-computed`, `#react-make`, `#tilia-react-type` to
  `./react/api.html#…`. Nothing redirects those today, and they are live URLs.

Also `react/package.json` has `"homepage": "https://tiliajs.dev/api"`; it becomes
`https://tiliajs.dev/react`, matching query's.

### 10. The tilia hero names the package

[docs/content/tilia/home/index.html](docs/content/tilia/home/index.html) calls `useTilia()`
under a `// React integration` comment in both language panes, while the footer beneath reads
`$ npm install tilia` — so the front page teaches an API the install line does not give you.
Name the package in the comment and make the footer `$ npm install tilia @tilia/react`.

### 11. react/llms.txt

`react/llms.txt` does not exist; the shell links and copies one per package. Write a short one
(the surface is five entries) modelled on `tilia/llms.txt`: `useTilia`, `useComputed`, `leaf`,
`make`, the `TiliaReact` type, and a line that React Native needs nothing extra. If it is
deferred, drop the `llms.txt` build entry and the shell's alternate link for react rather than
pointing at tilia's.

### 12. Tests

[docs/src/site.test.mjs](docs/src/site.test.mjs):

- add `react/index.html` and `react/api.html` to `pages`;
- the switcher test expects `options.length` 2 — it becomes 3, and the current-package name
  derivation (`page.startsWith("query/") ? "@tilia/query" : "tilia"`) needs a react branch;
- assert the react pages carry `<body class="react">` and no Guide link;
- assert the autumn block in the stylesheet, as the `body.query` accents are asserted nowhere
  today but the switcher styling test is the right home for it.

Optionally add a `#leaf` → `./react/api.html#leaf` assertion to
[docs/src/redirects.test.mjs](docs/src/redirects.test.mjs).

## Acceptance

- `cd docs && pnpm test` green, including `output.test.mjs`, which resolves every local href
  and every `#anchor` in the generated site — that is what proves the moves left nothing dangling.
- The switcher lists three packages on every page, with exactly one checked, and the react
  pages read russet: trigger label, selected option, nav pill, and the API tag chips.
- The react nav shows Home and API only; tilia and query still show Home, Guide, API.
- `tiliajs.dev/api.html#use-tilia`, `#leaf`, `#use-computed`, `guide.html#tilia-in-react` and
  the legacy `docs.html#usetilia` family all land on the new locations.
- The tilia guide reads straight through 9 → 10 → 11 → 12 with no mention of an API tilia
  does not ship.

## Watch out

- `refs:` frontmatter renders `./api.html#{{item}}` — package-local by construction. Any chapter
  citing a react slug from the tilia guide will dangle.
- Two copies of the legacy hash map exist. Changing one and not the other is the easy miss.
- The home fragment test forbids `<script>` in `content/*/home/index.html`; the hero toggle
  script belongs in the build entry's `scripts` var.
- `docs/src/audit-since.mjs` reads the react package's `.resi` files, not the docs tree — it is
  unaffected by the move.
