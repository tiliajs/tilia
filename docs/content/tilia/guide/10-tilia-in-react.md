---
title: tilia in React
slug: tilia-in-react
sort: 10
refs: [leaf, use-tilia, use-computed]
---

This chapter adds no scenario — and that is its finest feature. The deck, the session, today's date, the streak: all of it was built and verified without a pixel. Now the views arrive, the whole suite stays green and untouched, and the separation the bootstrap promised — business in features, no logic in views — stops being a promise and becomes an observable fact.

Views are observers. That one idea is the entire React integration: a component reads reactive values while rendering, and it should re-render exactly when one of those values changes. The `@tilia/react` package (installed separately) offers three tools, in a deliberate order of preference.

### leaf: the favored way

[`leaf`](api.html#leaf) wraps a component so that tilia tracks the reads of the render itself:

```typescript
import { leaf } from "@tilia/react";

const CardView = leaf(() => {
  const { deck } = useApp();
  const card = deck.queue[0];
  return card ? <div>{card.front}</div> : <AllDone />;
});
```

```rescript
open TiliaReact

@react.component
let make = leaf(() => {
  let {deck} = useApp()
  switch deck.queue[0] {
  | Some(card) => <div> {card.front->React.string} </div>
  | None => <AllDone />
  }
})
```

Because tracking happens during the render, the dependencies are *exact*: this component re-renders when `deck.queue` changes and not otherwise. No dependency array, no memoized selector, no `memo` wrapper. The component reads the domain; the subscription is the reading. And notice the component's vocabulary — `deck`, `queue`, `front`: a view Alice could read over Adèle's shoulder.

`useApp` is an architectural suggestion, not an API: provide the app object through an ordinary React context and let components pull the feature they need. Because tracking is fine-grained, one context for the whole app works seamlessly — and a test provides a mock app the same way. The world stays injected, even here.

::: story
The scheduler gets its face on a Saturday. Alice answers, the queue advances, and only the card on screen repaints — the streak counter, the deck list, the settings panel never notice. It feels less like a program updating and more like a page turning.
:::

::: pro
Take features from the context, not deep values: `const { deck } = useApp()`, then read `deck.queue` in the JSX where it is used. Destructuring everything at the top defeats the granularity of the tracking.
:::

### useTilia: the easy retrofit

[`useTilia`](api.html#use-tilia) is a hook called at the top of a component that makes the reads below it reactive:

```typescript
import { useTilia } from "@tilia/react";

const CardView = () => {
  useTilia();
  const card = app.deck.queue[0];
  return card ? <div>{card.front}</div> : <AllDone />;
};
```

```rescript
open TiliaReact

@react.component
let make = () => {
  useTilia()
  switch app.deck.queue[0] {
  | Some(card) => <div> {card.front->React.string} </div>
  | None => <AllDone />
  }
}
```

It is the fastest way to make an existing component reactive, and that is its role: a retrofit for gradual adoption. Its tracking is slightly coarser than `leaf`'s — a hook cannot see the exact end of its own render — so prefer `leaf` for new code; the [API reference](api.html#use-tilia) has the precise mechanics.

### useComputed: re-render on the answer

Sometimes a component depends on a *conclusion*, not the values behind it. Each row of Alice's queue wants to know one thing — am I the current card? [`useComputed`](api.html#use-computed) re-asks the question cheaply and re-renders only when *its own answer* flips:

```typescript
const current = useComputed(() => app.deck.queue[0]?.id === card.id);
```

```rescript
let current = useComputed(() =>
  app.deck.queue[0]->Option.map(c => c.id)->Option.getOr("") === card.id
)
```

Two rows repaint per advance, no matter how long the list.

Every piece of the scheduler — deck, session, today's date, streak, views — is now an object or a function that could be read aloud at the kitchen table. One question remains, and it is the one that decides whether the trust holds for years: what happens when someone gets it wrong?
