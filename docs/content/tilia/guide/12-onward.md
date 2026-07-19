---
title: Onward
slug: onward
sort: 12
refs: []
---

Step back and look at what got built, and how. A card is a plain object. A deck is a carved feature: state, derived queue, review action, injected repo and clock. The session is a state machine that only offers legal moves. The views read the domain and repaint exactly when their answer changes. Above it all sits a file of scenarios that Alice — who writes no code — has read, corrected, and signed. Nowhere is there a store, a reducer, an action type, or a subscription list.

The mental model compresses well:

- **The scenarios are the design.** Behavior is decided in the domain's words, and the running program is checked against them for life.
- **Objects live.** `tilia` makes a plain object reactive without changing its shape; separate objects share one forest.
- **Values follow.** `computed` and `derived` keep declared relationships true — pull, cached, nearly free to read.
- **The world is asked for, and flows in.** Services arrive injected — a clock you can set, a repo in memory — and `source` and `store` place external, self-managing values inside the same objects, under the same rules.
- **Time is coherent.** Writes notify immediately, except inside reactive callbacks and batches; `watch` separates cause from effect.
- **Mistakes stay small.** Definitions fail loudly at the source; a throwing observer is cleared, reported, and quarantined; every bug becomes a scenario.

And the deeper habit the library rewards is the one named in the first chapter's title: draw before building. It is what let three very different minds — a domain owner, a designer, and an AI who forgets everything between sessions — build one coherent thing without fear. The words carried; the suite verified; the joy stayed.

### Where to go from here

The [API reference](api.html) documents the complete public surface — every function, both languages, precise rules wherever this guide chose the readable ones.

The scheduler's repo was injected and politely ignored; synchronizing collections with a server — loading, caching, going offline and coming back — is its own discipline, with its own convictions. **[@tilia/query](query/index.html)** builds that lifecycle on the reactivity you now understand, and [its guide](query/guide.html) takes Alice somewhere with very bad reception.

The scenarios that ran green through every chapter were executed by **épure**, published as [@epure/vitest](https://www.npmjs.com/package/@epure/vitest) — the same project whose `bootstrap.md` started the empty directory in chapter 2. The method — software drawn before it is built — lives at [epuremethod.com](https://epuremethod.com), and its guide is this trilogy's prequel: where the drawings come from.

tilia itself is open source, at [github.com/tiliajs/tilia](https://github.com/tiliajs/tilia).

::: story
Alice knows none of this. She flips a card, the box learns, and tomorrow asks better questions. Adèle rereads the scenarios sometimes, like a diary of decisions. And Claudine remembers nothing at all — which turns out to be fine, because everything that matters is written down, in words all three of them share.
:::
