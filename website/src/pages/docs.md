---
layout: ../components/Layout.astro
title: Tilia Documentation - Complete API Reference & Guide
description: Complete documentation for Tilia state management library. Learn tilia, observe, computed, signal, store functions and React integration with useTilia hook.
keywords: tilia documentation, API reference, tila, observe, computed, useTilia, React hook, state management guide, TypeScript tutorial, ReScript tutorial, pull reactivity, push reactivity
---

<main class="container mx-auto px-6 py-8 max-w-4xl">
<section class="header">

# Documentation {.documentation}

Complete guide to using Tilia for simple and fast state management in TypeScript and ReScript applications. {.subtitle}

</section>

<section class="doc installation">

## Installation

Use the **canary** version (not yet released because the API might still change, but it is stable):

```bash
npm install tilia@canary
```

</section>

<section class="doc goals">

## Goals and Non-goals

<strong class="text-green-300">The goal</strong> with Tilia is to be minimal
and fast while staying out of the way. A special effort was made to keep
the API simple and intuitive.

We haven't measured the performance of the library yet, but everything was
designed to make it as fast and lightweight as possible. If someone wants to
help us benchmarking, we'd be happy to add this information to the
documentation. {.story}

<strong class="text-pink-300/80">Non-goal</strong> Tilia is not a framework.

</section>

## API Reference {.api}

<section class="doc tilia">

### tilia

Transform an object or array into a tilia value.

```typescript
import { tilia } from "tilia";

const alice = tilia({
  name: "Alice",
  birthday: dayjs("2015-05-24"),
  age: 10,
});
```

```rescript
open Tilia

let alice = tilia({
  name: "Alice",
  birthday: dayjs("2015-05-24"),
  age: 10,
})
```

Alice can now be observed. Who knows what she will be doing? {.story}

</section>

<section class="doc observe">

### observe

Observe and react to changes. When an observed value changes, the
callback is called (**push** reactivity).

When the callback is run, tilia registers which values are read in the
connected objects and arrays. The callback is always run at least once,
on creation.

```typescript
import { observe } from "tilia";

observe(() => {
  console.log("Alice is now", alice.age, "years old !!");
});

alice.age = 11; // ✨ This triggers the observe callback
```

```rescript
open Tilia

observe(() => {
  Js.log3("Alice is now", alice.age, "years old !!")
})

alice.age = 11; // ✨ This triggers the observe callback
```

**📖 Important Note:** If you mutate observed tilia values during the observe call, the callback
will be re-run as soon as it ends (to support state machines). {.note}

Now every time alice's age changes, the callback will be called. {.story}

</section>

<section class="doc computed wide-comment">

### computed

Compute a value from tilia values. The value is only computed when needed (**pull** reactivity).

```typescript
import { computed } from "tilia";

let globals = tilia({ now: dayjs() });
setInterval(() => (globals.now = dayjs()), 1000 * 60);

const alice = tilia({
  name: "Alice",
  birthday: dayjs("2015-05-24"),
  age: computed(() => globals.now.diff(alice.birthday, "year")),
});
```

```rescript
open Tilia
open Day

let globals = tilia({ now: now() })
setInterval(() => globals.now = now(), 1000 \* 60)

let alice = tilia({
  name: "Alice",
  birthday: dayjs("2015-05-24"),
  age: 0,
})
alice.age = computed(() => globals.now->diff(alice.birthday, "year"))
```

Nice, the age updates automatically, Alice can grow older :-) {.story}

**💡 Pro tip:** The computed only recomputes or notifies observers when needed. {.pro}

Once a value is computed, it behaves exactly like a regular value until it is expired due to a change in the dependencies. This means that there is nearly zero overhead for computed values acting as getters:

```typescript
// ✅ public.name is now read-only
const public = tilia({ name: computed(() => alice.name) });
```

```rescript
// ✅ public.name is now read-only
let public = tilia({ name: computed(() => alice.name) })
```

</section>

## Functional Reactive Programming {.frp}

✨ **Rainbow architect**, tilia has <span>2</span> more functions for you! ✨ {.rainbow}

Since Tilia lets you create your own FRP library, we’ll demonstrate how these two functions are implemented. {.subtitle}

<section class="doc signal wide-comment">

### signal

A signal represents a single, changing value of any type. It is the basic building block of an FRP library.

```typescript
type Signal<T> = { readonly value: T };
type Setter<T> = (v: T) => void;

function signal<T>(value: T): [Signal<T>, Setter<T>] {
  const s = tilia({ value });
  const set = (v: T) => (s.value = v);
  return [s, set];
}

// Usage
const [s, set] = signal(0);

set(1);
console.log(s.value);
// 🚨 Error: Cannot assign to 'value' because it is a read-only property.
s.value = 2;
```

```rescript
type signal<'a> = { value: 'a }
type setter<'a> = 'a => unit

let signal = value => {
  let s = tilia({ value: value })
  let set = v => ignore(Reflect.set(s, "value", v))
  (s, set)
}

// Usage
let (s, set) = signal(0)

set(1)
Js.log(s.value)
// 🚨 Error: The record field value is not mutable
s.value = 2
```

**📘 Notice** how a signal is simply a tilia object with a single field. {.note}

</section>

<section class="doc frp wide-comment store">

### store

A store is similar to a signal, but it changes how its setter works. Instead of making the setter available after the signal is created, the store function receives the setter as an argument. This design lets you build a state machine where the setter controls the state transitions through exposed functions.

```typescript
function store<T>(init: (setter: Setter<T>) => T): Signal<T> {
  const [s, set] = signal({}) as Signal<T>;
  set(init(set));
  return s;
}

// Usage (compare with ReScript 😉)
function loading(set: Setter<App>): App {
  return ({
    t: "Loading",
    loaded: (user: User) => set(ready(set, user))
  });
}

function ready(set: Setter<App>, user: User): App {
  return { t: "Ready", user, logout: () => set(loggedOut(set)) };
}

function loggedOut(set: Setter<App>): App {
  return { t: "LoggedOut", loading: () => set(loading(set)) };
}

const app = store(loggedOut);

// Test or use in your app

if app.value.t === "LoggedOut" {
  app.value.loading();
}

if app.value.t === "Loading" {
  app.value.loaded({ name: "Alice", username: "alice" });
}
```

```rescript
let store = init => {
  let (s, set) = signal(%raw(`undefined`))
  set(init(set))
  s
}

// Usage
let rec loading = set =>
  Loading({loaded: user => set(ready(set, user))})

and ready = (set, user) =>
  Ready({user, logout: () => set(loggedOut(set))})

and loggedOut = set =>
  LoggedOut({loading: () => set(loading(set))})


let app = store(loggedOut)

// Test or use in your app

switch app.value {
| LoggedOut(app) => app.loading()
| _ => t->fail("Not logged out")
}

switch app.value {
| Loading(app) => app.loaded({name: "Alice", username: "alice"})
| _ => t->fail("Not loading")
}

```

The `store` function is a very powerful tool to manage state transitions. Look at the [todo app](https://github.com/tiliajs/todo-app-ts) for a working example using TypeScript.

</section>

✨✨ Thanks to everyone who gave us feedback ✨✨ {.rainbow}

## React Integration {.react}

<section class="doc react">

### useTilia <small>(React Hook)</small>

#### Installation

```bash
npm install @tilia/react@canary
```

Insert `useTilia` at the top of the React components that consume tilia values.

```typescript
import { useTilia } from "@tilia/react";

function App() {
  useTilia();

  if (alice.age >= 13) {
    return <SocialMediaApp />;
  } else {
    return <NormalApp />;
  }
}
```

```rescript
open TiliaReact

@react.component
let make = () => {
  useTilia()

  if (alice.age >= 13) {
    <SocialMedia />
  } else {
    <NormalApp />
  }
}
```

**💡 Pro tip:** The App component will now re-render when `alice.age` changes because "age" was read from "alice" during the last render. {.pro}

</section>

<div class="flex flex-row space-x-4 justify-center items-center w-full gap-12">
  <a href="/compare"
    class="bg-gradient-to-r from-green-400 to-blue-500 px-6 py-3 rounded-full font-bold hover:scale-105 transform transition">
    Compared with...
  </a>
  <a href="https://github.com/tiliajs/tilia"
    class="border-2 border-white/50 px-6 py-3 rounded-full font-bold hover:bg-white/20 transition">
    GitHub
  </a>
</div>

<div class="bg-black/20 backdrop-blur-lg rounded-xl md:p-8 p-4 border border-white/20 my-8">
  <h2 class="text-3xl font-bold mb-6 text-transparent bg-clip-text bg-gradient-to-r from-green-400 to-blue-500">
    Main Features
  </h2>
  <div class="grid lg:grid-cols-2 lg:gap-6 gap-3">
    <div class="space-y-3">
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span class="font-bold text-green-300">Zero dependencies</span>
      </div>
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span>Optimized for stability and speed</span>
      </div>
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span>Highly granular reactivity</span>
      </div>
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span>Combines <strong>pull</strong> and <strong>push</strong> reactivity</span>
      </div>
    </div>
    <div class="space-y-3">
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span>Tracking follows moved or copied objects</span>
      </div>
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span>Compatible with ReScript and TypeScript</span>
      </div>
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span>Optimized computations (no recalculation)</span>
      </div>
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span>No god object or single state</span>
      </div>
    </div>
  </div>
</div>

<section class="doc examples">
  <h2 class="text-3xl font-bold mb-6 text-transparent bg-clip-text bg-gradient-to-r from-yellow-200 to-pink-900">
    Examples
  </h2>
  <div class="space-y-4 text-lg text-white/90">
    <p>
      You can check the <a href="https://github.com/tiliajs/tilia/blob/main/todo-app-ts/src/domain/feature/app.ts"
        class="text-blue-300 hover:text-blue-200 underline">todo app</a>
      for a working example using TypeScript.
    </p>
    <p>
      Look at <a href="https://github.com/tiliajs/tilia/blob/main/tilia/test/Tilia_test.res"
        class="text-blue-300 hover:text-blue-200 underline">tilia tests</a> for working examples using ReScript.
    </p>
  </div>
</section>

<section class="doc changelog">
  <h2 class="text-3xl font-bold mb-6 text-transparent bg-clip-text bg-gradient-to-r from-red-300 to-teal-900">
    Changelog
  </h2>
  <div class="space-y-6 text-white/90">
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2025-06-09 2.0.0 (canary version)</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Moved core to "tilia" npm package.</li>
        <li>Changed <code class="text-yellow-300">make</code> signature to build tilia context.</li>
        <li>Enable forest mode to observe across separated objects.</li>
        <li>Add <code class="text-yellow-300">computed</code> to compute values in branches.</li>
        <li>Moved <code class="text-yellow-300">observe</code> into tilia context.</li>
        <li>Added <code class="text-yellow-300">signal</code>, and <code class="text-yellow-300">store</code>
          for FRP style programming.
        </li>
        <li>Simplify <code class="text-yellow-300">useTilia</code> signature.</li>
        <li>Add garbage collection to improve performance.</li>
      </ul>
    </div>
    <div class="text-sm text-white/70">
      <p>See the full changelog in the <a href="https://github.com/tiliajs/tilia/blob/main/README.md"
          class="text-blue-300 hover:text-blue-200 underline">README</a>.</p>
    </div>
  </div>
</section>
</main>
