# TODO

- [ ] Orchestrate sync and pruning across multiple collections so they do not
      flood the app on boot or all run at the same time.
- [ ] State the query-language constraint explicitly in the `.resi`: queries
      are pure predicates over one row — no limits, no pagination, no
      aggregates — because join-on-upsert and full-result `set` semantics
      both break otherwise.
- [ ] Rejected ops overlay in dict order before the seq-ordered outbox
      (`applyPending`). With one rejection per id it mostly cannot matter,
      but it is the only place ordering is accidental rather than chosen.
      Make it deterministic (sort by seq) or note why it cannot matter.
- [ ] Restart-with-rejection scenario: the `.resi` promises the rejection
      resurfaces on its own after a restart (op reloads as pending, re-push
      fails again). Test it.
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
