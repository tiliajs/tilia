---
title: tilia in React
slug: tilia-in-react
sort: 8
refs: [leaf, use-tilia, use-computed]
---

Views are observers. That one idea is the entire React integration: a component reads reactive values while rendering, and it should re-render exactly when one of those values changes. The `@tilia/react` package (installed separately) offers three tools, in a deliberate order of preference.

### leaf: the favored way

`leaf` wraps a component so that tilia tracks the reads of the render itself:

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

::: story
Alice answers, the queue advances, and only the card on screen repaints. The streak counter, the deck list, the settings panel — none of them noticed.
:::

Because tracking happens during the render, the dependencies are *exact*: this component re-renders when `deck.queue` changes and not otherwise. There is no dependency array to maintain, no selector to memoize, no `memo` wrapper to reason about. The component reads the domain; the subscription is the reading.

`useApp` above is an architectural suggestion, not an API: provide the app object through an ordinary React context, and let components pull the feature they need. Because tracking is fine-grained and state is mutated in place, one context for the whole app works seamlessly — and tests provide a mock app the same way.

::: pro
Take features from the context, not deep values: `const { deck } = useApp()`, then read `deck.queue` in the JSX. Destructuring everything at the top (`const { queue, streak } = ...`) defeats the granularity of dependency tracking — and reading `deck.queue` where it is used keeps the JSX legible and refactoring easy.
:::

### useTilia: the easy retrofit

[`useTilia`](api.html#use-tilia) is a hook called at the top of a component, and it makes the reads below it reactive:

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

It is the fastest way to make an existing component reactive, and that is its role: a retrofit. A hook cannot see the end of the render it belongs to, so tracking stays open until React runs the effects — by then the children have rendered too, and their reads are swept into the parent's dependencies. `leaf` closes tracking itself, at the exact end of the wrapped render, which is why its dependencies are exact. Both still lean on `useEffect` for the rest: notifications are armed only once the component is mounted, and the observer is cleared on unmount. Prefer `leaf`; keep `useTilia` for gradual adoption.

### useComputed: re-render on the answer, not the question

Sometimes a component depends on a *conclusion*, not on the values behind it. Each row of Alice's queue wants to know one thing: am I the current card?

```typescript
import { useTilia, useComputed } from "@tilia/react";

const Row = ({ card }: { card: Card }) => {
  useTilia();

  const current = useComputed(() => app.deck.queue[0]?.id === card.id);

  return <div className={current ? "current" : ""}>{card.front}</div>;
};
```

```rescript
open TiliaReact

@react.component
let make = (~card) => {
  useTilia()

  let current = useComputed(() => {
    switch app.deck.queue[0] {
    | Some(c) => c.id === card.id
    | None => false
    }
  })

  <div className={current ? "current" : ""}> {card.front->React.string} </div>
}
```

Without `useComputed`, every row depends on the head of the queue and all of them re-render whenever it moves. With it, each row depends on a boolean and re-renders only when *its own answer* flips — two rows per advance, no matter how long the list. The question is re-asked cheaply; the re-render is reserved for a changed answer.

The scheduler now has a face, and every piece of it — deck, session, clock, views — is an object or a function you could read aloud to Alice. What remains is the safety net underneath: what tilia does when code gets it wrong.
