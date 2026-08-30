# TODO

- [ ] Rewrite the tilia/query guide.

      FOCUSSING ON THE STORY, not the technical details which belong in the Reference.

      The goal of the guide is to inspire and give a FEELING of how things work. The guide should be a recreative read out of curiosity, not a highly engaging intellectual challenge.
- [ ] Add TypeScript type guards for loadable states such as `loading` and
      `loaded`, so narrowing preserves the data type:
      ```ts
      if (loading(spanish)) render(skeleton)
      else if (loaded(spanish)) render(spanish.data) // Card[] — an empty deck included
      ```
- [ ] Orchestrate sync and pruning across multiple collections so they do not
      flood the app on boot or all run at the same time.
- [ ] State the query-language constraint explicitly in the `.resi`: queries
      are pure predicates over one row — no limits, no pagination, no
      aggregates — because join-on-upsert and full-result `set` semantics
      both break otherwise.
- [ ] The api reference and guide are a generation behind: `dismiss` (2d
      replaced it with `retry` and `discard`), the old `loadable`, and now the
      whole of phase 4 — `store:` and the tuple return, `Store.make` /
      `Store.custom`, `Kv` and `persist`, `lookup`. `src/index.d.ts` is
      current as of 5c and is the closest thing to a written surface; the
      guide and `docs/content/query/api/**` are not. Belongs with the doc
      rewrite, once 4d has settled the packaging.
- [ ] Restart-with-rejection scenario: the `.resi` promises the rejection
      resurfaces on its own after a restart (op reloads as pending, re-push
      fails again). Test it.
- [x] Rejected ops overlay in dict order before the seq-ordered outbox
      (`applyPending`). Stale: rejections are status records, not optimistic
      overlays — `applyPending` folds the outbox alone, and a rejected op has
      already reverted, so overlaying one would show refused work again. The
      ordering that did matter is `status.rejected` itself, now inserted in
      operation order rather than reply-arrival order (2d, rule 13).
- [x] Document the linear-scan bet: `upsert` walks every entry and registry
      record, `applyPending` re-applies the whole outbox per delivery. Fine
      at client-cache scale (dozens of queries); say so rather than betting
      silently. → "The linear-scan bet" in `TECHNICAL.md`, echoed in
      `README.md` and `llms.txt`.
- [x] `README.md` and `docs/technical.md` still describe the pre-`live` API
      generation (`covered`, `status.error`, `channel.state`,
      `saved`/`conflict`/`rejected`). → `README.md` and `llms.txt` rewritten
      from `TiliaQuery.resi` + `TECHNICAL.md`; `docs/technical.md` removed
      (still-true content merged into `TECHNICAL.md`).
- [x] Implement inbound subscriptions.
  - [x] Apply values delivered through `receive.changed`.
  - [x] Apply ids delivered through `receive.removed`.
- [x] Give `live` queries a way to shut down: `channel.end` demotes the
      query back into normal refresh and `channel.finally` registers the
      source teardown, run once when the fetch closes (end, superseded,
      evicted, disposed). Late callbacks from a closed fetch are suppressed
      by the engine.


# BEFORE RELEASE !!! IMPORTANT

- [ ] Fix guide 07 "when the world returns" with the new type for TiliaQuery's `change`.