# Documentation and Theme Updates Plan (updated 2025-12-12)

Legend: ✅ done · 🟡 partial · ⬜ not started

## Current repo status

- Modified: `website/src/styles/prism-shades.css`
- New: `tilia/orphan-computations.md`
- New: `website/src/pages/errors.md`
- New: `website/src/pages/guide-fr.md`

## Task 1: Move Orphan Computations to Website

**Goal:** Make `website/src/pages/errors.md` the canonical doc page for orphan computations.

- ✅ `website/src/pages/errors.md` exists and is already using the site docs layout/frontmatter.
- 🟡 `tilia/orphan-computations.md` still exists as a separate file (duplicated content, older code fences).

**Next steps**
- ⬜ Decide canonical source: keep only `website/src/pages/errors.md`.
- ⬜ Remove `tilia/orphan-computations.md` or replace it with a short link/redirect note pointing to `/errors`.
- ⬜ Double-check internal links in `errors.md` (e.g. API reference should point to `/docs`, not GitHub wiki).

## Task 2: Add ReScript Code Blocks (Errors)

- ✅ `errors.md` has paired code blocks: **15** `typescript` + **15** `rescript`.

**Next steps**
- ⬜ Spot-check ReScript examples compile/are idiomatic (optional, but recommended).

## Task 3: Transform `guide-fr.md` to match documentation format

- 🟡 `website/src/pages/guide-fr.md` exists, but it’s not yet in the website “doc page” format.
- ⬜ No `rescript` code blocks yet (currently **59** `typescript`, **0** `rescript`).

**Next steps**
- ⬜ Add frontmatter matching `docs.md` (`layout`, `title`, `description`, `keywords`).
- ⬜ Wrap content into `<main ...>` and `<section class="doc ...">` blocks like `docs.md`.
- ⬜ Convert examples to dual blocks (TypeScript then ReScript) following the toggle system.
- ⬜ Add/normalize anchors for major sections.

## Task 4: Translate API Docs to French

- ⬜ `website/src/pages/docs-fr.md` does not exist yet.

**Next steps**
- ⬜ Create `docs-fr.md` as a translation of `docs.md` (keep structure, anchors, section classes, and code blocks unchanged).

## Task 5: Translate `guide-fr.md` to English

- ⬜ `website/src/pages/guide.md` does not exist yet.

**Next steps**
- ⬜ Create `guide.md` as an English translation of `guide-fr.md`.
- ⬜ Translate prose (and code comments), keep identifiers and API names unchanged.

## Task 6: Implement Light Theme with Selector

- ⬜ No theme toggle logic in `website/src/components/Layout.astro` yet.
- ⬜ No light-theme styling in `website/src/styles/global.css` yet.
- 🟡 Syntax highlighting styling has been tweaked (`prism-shades.css`), but it’s not wired to a light theme.

**Next steps**
- ⬜ Add theme toggle button (next to GitHub link) in `Layout.astro`.
- ⬜ Persist theme in `localStorage` and apply via `data-theme` (or a class) on `<html>`.
- ⬜ Default theme: `dark`.
- ⬜ Add light theme styles (background, text, links, panels, code blocks) in `global.css`.
- ⬜ Ensure both themes keep good contrast/accessibility.
