---
title: Views are observers
slug: views-are-observers
sort: 10
refs: []
chapter: "10"
---

This chapter adds no scenario. The deck, the session, today's date, the streak: all of it was built and verified without a pixel. Now the views arrive, and the suite stays green, untouched — business in features, no logic in views, exactly as `CONTRIBUTING.md` promised.

Views are observers. That one idea is everything an interface adds to what you have read so far: a component reads reactive values while it renders, and it repaints exactly when one of those values changes. There is no selector to write, no subscription to register, no store to connect to — the reading *is* the subscription. And the vocabulary on screen stays the domain's: `deck`, `queue`, `front`, words Alice could read over Adèle's shoulder.

It is also why the interesting part of the scheduler was finished before a single component existed. A view that only reads has nothing left to decide, so it cannot quietly hold a rule that no scenario covers.

::: story
The scheduler gets its face on a Saturday. Alice answers, the queue advances, and only the card on screen repaints — the streak counter, the deck list, the settings panel never notice. It feels less like a program updating and more like a page turning.
:::

### Giving it a face

React has its own package, **[@tilia/react](./react/index.html)**, and three tools in a deliberate order of preference: `leaf` wraps a component so the render's own reads are tracked exactly, `useTilia` retrofits a component you already have, and `useComputed` repaints on an answer rather than on the values behind it. Its home page walks through all three — and shows the same component in React Native, which needs nothing extra: the reactivity does not know that a renderer exists.

Every piece of the scheduler — deck, session, today's date, streak, views — is now an object or a function that could be read aloud at the kitchen table. One question remains: what happens when someone gets it wrong?
