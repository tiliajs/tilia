---
layout: ../components/Layout.astro
title: Tilia - Comparison with Other State Management Libraries
description: Compare Tilia with other state management libraries, aiming to be as (dis)honest as possible, including Zustand, Jotai, Recoil.
keywords: state management, comparison, jotai, recoil, zustand, React, JavaScript, reactive programming, FRP, proxy tracking, zero dependencies, performance, pull reactivity, push reactivity
---

<main class="container mx-auto px-6 py-8 max-w-4xl flex flex-col">
<section class="header comparaison">

# Comparison {.comparaison}

We'll compare Tilia with other state management libraries, aiming to be as <span class="opacity-50">(dis)</span>honest as possible. {.subtitle}

</section>

<section class="doc summary wide-comment">

## Feature Comparison Table {.table}

| Feature / Library                  | **Tilia** | **Jotai** | **Recoil** | **RxJS** |
| :--------------------------------- | :-------: | :-------: | :--------: | :------: |
| Zero dependencies, small bundle    |    ✅     |    ✅     |    _❌_    |   _❌_   |
| Highly granular reactivity         |    ✅     |    ✅     |     ✅     |   _❌_   |
| Combines pull \& push reactivity   |    ✅     |   _❌_    |    _❌_    |    ✅    |
| Signals \& stores (FRP primitives) |    ✅     |   _❌_    |    _❌_    |    ✅    |
| Batching/optimized computations    |    ✅     |   _❌_    |    _❌_    |    ✅    |
| React integration (hooks)          |    ✅     |    ✅     |     ✅     |   _❌_   |
| TypeScript support                 |    ✅     |    ✅     |     ✅     |    ✅    |
| ReScript support                   |    ✅     |   _❌_    |    _❌_    |   _❌_   |
| Persistence utilities              |   _❌_    |    ✅     |     ✅     |   _❌_   |
| Low boilerplate/learning curve     |    ✅     |    ✅     |     ✅     |   _❌_   |
| Large ecosystem/community          |   _❌_    |    ✅     |     ✅     |    ✅    |

## Performance {.performance}

These tests measure the raw performance of the libraries without going into the
details of how a granular update in a web application can help with app
reactivity or exploring the cases where Tilia shines (large forms, dynamic
graphs, etc).

| Description   | Tilia  | Tilia (batch) | Jotai       | RxJS    |
| :------------ | :----- | :------------ | :---------- | :------ |
| Fixed graph   | 93 ms  | 44 ms         | 33 ms       | _15 ms_ |
| File swaps    | 69 ms  | 64 ms         | 42 ms       | _26 ms_ |
| Dynamic graph | 145 ms | 129 ms        | _126 ms_ \* | 971 ms  |

\* The value computed by Jotai for this test is not the same as the one computed
by other libraries (no idea why).

We measure the time to do 100 steps: swap and updates operation, then compute
the sum.

```jsx
sum <-- [random of 1/2 users] <-- [folders] <-- [files]
```

- **Fixed graph**: 1 user, 1 folder, 1000 files, 10 updates, 0 swaps.
- **File swaps**: 1 user, 50 folders, 1000 files (40/folder), 10 updates, 10 swaps, 100 steps.
- **Dynamic graph**: 20 user, 30 folder (10/user), 1000 files (80/folder), 10 updates, 30 swaps.

Detail of the benchmark can be found [here](https://github.com/tiliajs/tilia/tree/main/performance).

</section>

<section class="doc zustand wide-comment">

## Zustand

A state management library for React with a focus on immutability. [Zustand docs](https://zustand.docs.pmnd.rs/).

```jsx
// Zustand
import { create } from "zustand";

const useStore = create((set) => ({
  bears: 0,
  increasePopulation: () => set((state) => ({ bears: state.bears + 1 })),
  removeAllBears: () => set({ bears: 0 }),
  updateBears: (newBears) => set({ bears: newBears }),
}));

// Zustand (usage in React components)
function BearCounter() {
  const bears = useStore((state) => state.bears);
  return <h1>{bears} bears around here...</h1>;
}

function Controls() {
  const increasePopulation = useStore((state) => state.increasePopulation);
  return <button onClick={increasePopulation}>one up</button>;
}
```

Tilia has a simpler syntax and has been designed to work seamlessly outside of
the presentation view (separation of business logic and UI).

```jsx
// Tilia supporting industry best practices.
import { tilia } from "tilia";

function bearFeature() {
  const bears = tilia({ count: 0 });

  return tilia({
    count: computed(() => bears.count),
    increasePopulation: () => bears.count++,
    removeAllBears: () => (bears.count = 0),
    updateBears: (newBears) => (bears.count = newBears),
  });
}

// Create the bear feature (possibly injecting dependencies).
const bears = bearFeature();

// You can test the bear feature outside of the presentation layer.
describe("bear feature", () => {
  it("should notify on increased bear population", () => {
    let count = 0;
    observe(() => {
      count = bears.count;
    });
    bears.increasePopulation();
    expect(count).toBe(1);
  });
});

// Consume state in components without logic.
import { useTilia } from "@tilia/react";

function BearCounter() {
  useTilia();
  return <h1>{bears.count} bears around here...</h1>;
}

function Controls() {
  useTilia();
  return <button onClick={bears.increasePopulation}>one up</button>;
}
```

**📖 Pro tip:** With tilia, your team can build highly performant applications while maintaining industry best practices around separation of concerns, behavior driven development, and immutability. {.pro}

The [todo app](https://github.com/tiliajs/todo-app-ts) is a great example of an application built with Tilia and using the Diagonal Architecture pattern (separation of concerns, dependency injection, state machines).

</section>

<section class="doc jotai wide-comment">

## Jotai

Jotai is a state management library that is focused on React integration but that can also be used in "vanilla" mode.

```jsx
// Jotai
import { atom, createStore } from "jotai";
const store = createStore();

const nameAtom = atom("Alice");
const ageAtom = atom(10);
const writableAgeAtom = atom(
  (get) => get(ageAtom),
  (_, set, v) => set(ageAtom, v)
);

const derivedAtom = atom((get) => get(nameAtom).toLowerCase());

const unsub = store.sub(ageAtom, (ageAtom) => {
  console.log("age changed to", store.get(ageAtom));
});
store.set(writableAgeAtom, 12);

// Jotai (usage in React components)
function App() {
  const name = useAtom(nameAtom);
  const age = useAtom(ageAtom);
  return (
    <h1>
      {name} is {age} years old
    </h1>
  );
}
```

The same example with Tilia:

```jsx
// Tilia
import { tilia, computed, observe } from "tilia";

const user = tilia({
  name: "Alice",
  username: computed(() => user.name.toLowerCase()),
  age: 10,
});

observe(() => {
  console.log("age changed to", user.age);
});
user.age = 12;

// Tilia (usage in React components)
import { useTilia } from "@tilia/react";

function App() {
  useTilia();
  return (
    <h1>
      {user.name} is {user.age} years old
    </h1>
  );
}
```

The types in tila are simpler: you use the native types and features of the
programming language to declare if a value is `mutable` (ReScript) or `readonly`
(TypeScript).

Tilia has a powerful `batch` mechanism that lets you implement world state
transitions (batch updates). This is not possible with jotai (as of now) where
updates are synchronous.

**💡 Pro tip:** Tilia does not require a provider and makes it easy to update and track complex state. {.pro}

</section>

<section class="doc recoil wide-comment">

## Recoil

Recoil is a minimal and "Reactish" state management library.

```jsx
// Recoil
import { atom, selector, useRecoilState, useRecoilValue } from "recoil";

const nameAtom = atom({
  key: "name",
  default: "Alice",
});

const ageAtom = atom({
  key: "age",
  default: 10,
});

const derivedAtom = selector({
  key: "username",
  get: ({ get }) => get(nameAtom).toLowerCase(),
});

function App() {
  const [name, setName] = useRecoilState(nameAtom);
  const age = useRecoilValue(ageAtom);

  const onChange = (e) => {
    setName(e.target.value);
  };
  return (
    <div>
      <input value={name} onChange={onChange} />
      <h1>
        {name} is {age} years old
      </h1>
    </div>
  );
}
```

The same example with Tilia:

```jsx
// Tilia
import { tilia } from "tilia";

const user = tilia({
  name: "Alice",
  username: computed(() => user.name.toLowerCase()),
  age: 10,
});

// Tilia (usage in React components)
import { useTilia } from "@tilia/react";

function App() {
  useTilia();

  const onChange = (e) => {
    user.name = e.target.value;
  };
  return (
    <div>
      <input value={user.name} onChange={onChange} />
      <h1>
        {user.name} is {user.age} years old
      </h1>
    </div>
  );
}
```

**💡 Pro tip:** Tilia does not require a root provider (RecoilRoot) and makes it easier to update and track complex state. {.pro}

</section>

<section class="doc nocomp wide-comment">

## Features not in the comparison

Some advanced uses that have not been covered in the examples so far.

### Data driven applications and performance

When building data-driven applications, it’s important to manage performance when objects or arrays are moved or reassigned between different data structures, especially if you want to maintain the same references for tracking purposes.

For example, if you update a single user in a computed, sorted list of users, you want to avoid re-rendering the entire list each time a change occurs. This requires a shallow move—transferring the object while preserving its identity—so that updates are efficiently tracked from multiple places without unnecessary rendering or processing

```jsx
const store = tilia({
  data: {
    alice: { name: "Alice", age: 10 },
    bob: { name: "Bob", age: 12 },
    charlie: { name: "Charlie", age: 8 },
  },
  // Shallow move preserving object identity
  sortedData: computed(() =>
    Object.values(store.data).sort((a, b) => a.age - b.age)
  ),
});

// Updates the user in the sorted list (without recomputing the list) this leads to optimal rendering performance.
function updateName(id: string, name: string) {
  store.data[id].name = name;
}
```

### Events during the render phase

The state can be updated during React's render phase. This is normally not wished but there are cases where it is useful such as updating the application state in response to a rendering issue (missing translation, rendering error, etc). With Tilia, your state is really in control and does not depend on which phase of the render lifecycle your rendering library is in.

</section>

</main>
