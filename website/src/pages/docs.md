---
layout: ../components/Layout.astro
title: Tilia Documentation - Complete API Reference & Guide
description: Complete documentation for Tilia state management library. Learn tilia, carve, observe, signal, batch, computed, derived, source functions and React integration with useTilia, and useComputed hooks.
keywords: tilia documentation, API reference, tila, carve, domain-driven design, ddd, observe, signal, computed, derived, source, useTilia, useComputed, React hook, state management guide, TypeScript tutorial, ReScript tutorial, pull reactivity, push reactivity
---

<main class="container mx-auto px-6 py-8 max-w-4xl">
<section class="header">

# Documentation {.documentation}

Complete guide to using Tilia for simple and fast state management in TypeScript and ReScript applications. {.subtitle}

</section>

<a id="installation"></a>

<section class="doc installation">

## Installation

Use the **beta** version (not yet released API mostly stable):

```bash
npm install tilia@beta
```

</section>

<a id="goals"></a>

<section class="doc goals">

## Goals and Non-goals

<strong class="text-green-300">The goal</strong> of Tilia is to provide a
minimal and fast state management solution that supports domain-oriented
development (such as Clean or Diagonal Architecture). Tilia is designed so that
your code looks and feels like domain logic, rather than being cluttered with
library-specific details.

<strong class="text-red-200">Non-goal</strong> Tilia is not a framework.

</section>

## API Reference {.api}

<a id="tilia"></a>

<section class="doc tilia">

### tilia

Transform an object or array into a reactive tilia value.

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

<a id="observe"></a>

<section class="doc observe">

### observe

Use observe to monitor changes and react automatically. When an observed value
changes, your callback function is triggered (**push** reactivity).

During the callback’s execution, Tilia tracks which properties are accessed in
the connected objects and arrays. The callback always runs at least once when
observe is first set up.

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

**📖 Important Note:** If you mutate observed tilia values during the observe
call, the callback will be re-run as soon as it ends. {.note}

Now every time alice's age changes, the callback will be called. {.story}

</section>

<a id="batch"></a>

<section class="doc batch wide-comment">

### batch

Group multiple updates to prevent redundant notifications. This can be required
for managing complex update cycles—such as in games—where atomic state changes
are essential.

**💡 Pro tip** `batch` is not required in `computed`, `source` or `observe`
where notifications are already blocked. {.pro}

```typescript
import { batch } from "tilia";

network.subscribe((updates) => {
  batch(() => {
    for (const update in updates) {
      app.process(update);
    }
  });
  // ✨ Notifications happen here
});
```

```rescript
open Tilia

network.subscribe(updates => {
  batch(() => {
    for update in updates {
      app.process(update)
    }
  })
  // ✨ Notifications happen here
})
```

</section>

## Functional Reactive Programming {.frp}

✨ **Rainbow architect**, tilia has <span>5</span> more functions for you! ✨ {.rainbow}

Before introducing each one, let us show you an overview. {.subtitle}

<a id="patterns"></a>

<section class="doc patterns wide-comment summary frp">

| Pattern         | Use-case                                | Tree param | Setter | Return value |
| :-------------- | :-------------------------------------- | :--------: | :----: | ------------ |
| `computed`      | Computed value from external sources    |   ❌ No    | ❌ No  | ✅ Yes       |
| `carve derived` | Cross-property computation              |   ✅ Yes   | ❌ No  | ✅ Yes       |
| `source`        | External/async updates                  |   ❌ No    | ✅ Yes | ❌ No        |
| `readonly`      | Avoid tracking on (large) readonly data |            |        |              |

And `signal` which is just a shorthand for `tilia({ value: v })`.

</section>

<a id="computed"></a>

<section class="doc computed wide-comment computed">

### computed

Return a computed value to be inserted in a Tilia object.

The value is computed when the key is read (**pull** reactivity) and is
destroyed (invalidated) when any observed value changes.

```typescript
import { computed } from "tilia";

const globals = tilia({ now: dayjs() });

setInterval(() => (globals.now = dayjs()), 1000 * 60);

const alice = tilia({
  name: "Alice",
  birthday: dayjs("2015-05-24"),
  // The value 'age' is always up-to-date
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

**💡 Pro tip:** The computed can be created anywhere but only becomes active
inside a Tilia object or array. {.pro}

Once a value is computed, it behaves exactly like a regular value until it is
expired due to a change in the dependencies. This means that there is nearly
zero overhead for computed values acting as getters.

</section>

<a id="source"></a>

<section class="doc frp wide-comment source">

### source

Return a reactive source to be inserted into a Tilia object.

A source is similar to a computed, but it receives a setter function and does
not return a value. The setup callback is called on first value read and
whenever any observed value changes. The initial value is used before the first
set call.

```typescript
const app = tilia({
  // Async data (re-)loader (setup will re-run when alice's age changes.
  social: source(
    (set) => {
      if (alice.age > 13) {
        fetchData(set);
      } else {
        set({ t: "NotAvailable" });
      }
    },
    { t: "Loading" }
  ),
  // Subscription to async event (online status)
  online: source(subscribeOnline, false),
});
```

```rescript
let app = tilia({
  // Async data (re-)loader (setup will re-run when alice's age changes.
  social: source(
    set => {
      // "social" setup will re-run when alice's age changes
      if (alice.age > 13) {
        fetchData(set)
      } else {
        set(NotAvailable)
      }
    },
    Loading
  ),
  // Subscription to async event (online status)
  online: source(subscribeOnline, false),
})
```

The see different uses of `source`, `store` and `computed`, you can have a look
at the [todo app](/todo-app-ts).

</section>

<a id="readonly"></a>

<section class="doc frp wide-comment readonly">

### readonly

A tiny helper to mark a field as readonly (and thus not track changes to its
fields):

```typescript
import { type Readonly, readonly } from "tilia";

const app = tilia({
  form: readonly(bigStaticData),
});

// Original `bigStaticData` without tracking
const data = app.form.data;

// 🚨 'set' on proxy: trap returned falsish for property 'data'
app.form.data = { other: "data" };
```

```rescript
open Tilia

let app = tilia({
  form: readonly(bigStaticData),
})

// Original `bigStaticData` without tracking
let data = app.form.data

// 🚨 'set' on proxy: trap returned falsish for property 'data'
app.form.data = { other: "data" }
```

</section>

<a id="signal"></a>

<section class="doc frp wide-comment signal">

### signal

A signal represents a single, changing value of any type.

This is a tiny wrapper around `tilia` to expose a single, changing value.

```typescript
type Signal<T> = { value: T };

function signal<T>(value: T): Signal<T> {
  return tilia({ value });
}

// Usage

const s = signal(0);

s.value = 1;
console.log(s.value);
```

```rescript
type signal<'a> = {mutable value: 'a}

let signal = value => tilia({value: value})

// Usage

let s = signal(0)

s.value = 1
Js.log(s.value)
```

**🌱 Small tip**: Using `tilia` with your own field names is usually prefered to `signal` as it reflects your domain:

```typescript
// ✅ Domain-driven
const app = tilia({
  authenticated: false,
  now: store(runningTime),
});

if (app.authenticated) {
}

// 🌧️ Less readable
const authenticated_ = signal(false);
const now_ = signal(store(runningTime));

if (authenticated_.value) {
}
```

```rescript
// ✅ Domain-driven
let app = tilia({
  authenticated: false,
  now: store(runningTime),
})

if app.authenticated {
}

// 🌧️ Less readable
let authenticated_ = signal(false)
let now_ = signal(store(runningTime))

if (authenticated_.value) {
}
```

</section>
<a id="carve"></a>

## <span>✨</span> Carving <span>✨</span> {.carve}

<section class="doc computed wide-comment carve">

### carve (derived)

This is where Tilia truly shines. It lets you build a domain-driven, self-contained feature that is easy to test and reuse.

```rescript
open Tilia

let feature = carve(({ derived }) => { ... fields })
```

The `derived` function in the carve argument is like a `computed` but with the
object itself as first parameter.

### Example

```typescript
import { carve } from "tilia";

// A pure function for sorting todos, easy to test in isolation.
function list(todos) {
  const compare = todos.sort === "by date"
    ? (a, b) => a.createdAt.localeCompare(b.createdAt)
    : (a, b) => a.title.localeCompare(b.title);
  return [...todos.data].sort(compare);
}

// A pure function for toggling a todo, also easily testable.
function toggle({ data, repo }: Todos) {
  return (id: string) => {
    const todo = data.find(t => t.id === id);
    if (todo) {
      todo.completed = !todo.completed;
      repo.save(todo)
    } else {
      throw new Error(`Todo ${id} not found`);
    }
  };
}

// Injecting the dependency "repo"
function makeTodos(repo: Repo) {
  // ✨ Carve the todos feature ✨
  return carve({ derived }) => ({
    sort: "by date",
    list: derived(list),
    data: source(repo.fetchTodos, []),
    toggle: derived(toggle),
    repo,
  });
}
```

```rescript
open Tilia

// A pure function for sorting todos, easy to test in isolation.
let list = todos =>
  todos->Array.toSorted(switch todos.sort {
    | ByDate => (a, b) => String.compare(a.createdAt, b.createdAt)
    | ByTitle => (a, b) => String.compare(a.title, b.title)
  })

// A pure function for toggling a todo, also easily testable.
let toggle = ({ data, repo }: Todos.t) =>
  switch data->Array.find(t => t.id === id) {
    | None => raise(Not_found)
    | Some(todo) =>
      todo.completed = !todo.completed
      repo.save(todo)
  }

// Injecting the dependency "repo"
let makeTodos = repo =>
  // ✨ Carve the todos feature ✨
  carve(({ derived }) => {
    sort: ByDate,
    list: derived(list),
    data: source(repo.fetchTodos, []),
    toggle: derived(toggle),
  })
```

**💡 Pro tip:** Carving is a powerful way to build domain-driven, self-contained features. Extracting logic into pure functions (like `list` and `toggle`) makes testing and reuse easy. {.pro}

#### Recursive derivation (state machines)

For recursive derivation (such as state machines), use `source`:

```typescript
derived((tree) => source(machine, initialValue));
```

```rescript
derived(tree => source(machine, initialValue))
```

This allows you to create dynamic or self-referential state that reacts to
changes in other parts of the tree.

<div class="text-center text-3xl text-black hue-rotate-230">💡</div>

#### Difference from `computed`

- Use `computed` for pure derived values that do **not** depend on the entire object.
- Use `derived` (via `carve`) when you need access to the full reactive object
  for cross-property logic or methods.

Look at <a href="https://github.com/tiliajs/tilia/blob/main/todo-app-ts/src/domain/feature/todos/todos.ts">todos.ts</a> for an example of using `carve` to build the todos feature.

</section>
<a id="react"></a>

## React Integration {.react}

<section class="doc react useTilia">

### useTilia <small>(React Hook)</small> {.useTilia}

#### Installation

```bash
npm install @tilia/react@beta
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

The App component will now re-render when `alice.age` changes because "age" was read from "alice" during the last render.

</section>

<a id="useComputed"></a>

<section class="doc react useComputed">

### useComputed <small>(React Hook)</small> {.useComputed}

`useComputed` lets you compute a value and only re-render if the result changes.

```typescript
import { useTilia, useComputed } from "@tilia/react";

function TodoView({ todo }: { todo: Todo }) {
  useTilia();

  const selected = useComputed(() => app.todos.selected.id === todo.id);

  return <div className={selected.value ? "text-pink-200" : ""}>...</div>;
}
```

```rescript
open TiliaReact

@react.component
let make = () => {
  useTilia()

  let selected = useComputed(() => app.todos.selected.id === todo.id)

  <div className={selected.value ? "text-pink-200" : ""}>...</div>;
}
```

With this helper, the TodoView does not depend on `app.todos.selected.id` but on `selected.value`. This prevents the component from re-rendering on every change to the selected todo.

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
        <span>Optimized computations (no recalculation, batch processing)</span>
      </div>
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span>Tiny footprint (8KB) ✨</span>
      </div>
    </div>
  </div>
</div>
<a id="ddd"></a>

<section class="doc ddd">

## Why Tilia Helps with Domain-Driven Design {.ddd}

**Domain-Driven Design (DDD)** is a methodology that centers software around the core business domain, using a shared language between developers and domain experts, and structuring code to reflect real business concepts and processes<sup><a href="#ref-1">1</a></sup><sup><a href="#ref-2">2</a></sup><sup><a href="#ref-3">3</a></sup>. Tilia’s design and features directly support these DDD goals in several ways:

- **Ubiquitous Language in Code:**
  Tilia’s API encourages you to model your application state using the same terms and structures that exist in your business domain. With minimal boilerplate and no imposed framework-specific terminology, your codebase can closely mirror the language and logic of your domain, making it easier for both developers and domain experts to understand and collaborate<sup><a href="#ref-1">1</a></sup><sup><a href="#ref-2">2</a></sup>.
- **Bounded Contexts and Modularity:**
  Tilia enables you to compose state into clear, isolated modules (using `carve`, for example), which naturally map to DDD’s concept of bounded contexts. Each feature or subdomain can be managed independently, reducing complexity and making it easier to evolve or refactor parts of your system as business requirements change<sup><a href="#ref-1">1</a></sup><sup><a href="#ref-3">3</a></sup>.
- **Rich Domain Models:**
  By allowing you to define computed properties, derived state, and domain-specific actions directly within your state objects, Tilia helps you build rich domain models. This keeps business logic close to the data it operates on, improving maintainability and clarity<sup><a href="#ref-1">1</a></sup><sup><a href="#ref-2">2</a></sup>.
- **Continuous Evolution:**
  Tilia’s reactive model and compositional API make it easy to refactor and extend your domain models as your understanding of the business evolves. This aligns with DDD’s emphasis on evolutionary design and ongoing collaboration with domain experts<sup><a href="#ref-3">3</a></sup>.
- **Improved Communication and Onboarding:**
  Because Tilia encourages code that reads like your business language, new team members and stakeholders can more quickly understand the system. This reduces onboarding time and the risk of miscommunication between technical and non-technical team members<sup><a href="#ref-2">2</a></sup>.
- **Testability and Isolation:**
  Tilia’s modular state and clear separation between state, actions, and derived values enable you to test domain logic in isolation, a key DDD best practice<sup><a href="#ref-4">4</a></sup>.

**In summary:**
Tilia’s minimal, expressive API and focus on modeling state and logic directly in the language of your business domain make it an excellent fit for domain-driven design. It helps you produce code that is understandable, maintainable, and closely aligned with business needs—while making it easier to manage complexity and adapt to change<sup><a href="#ref-1">1</a></sup><sup><a href="#ref-2">2</a></sup><sup><a href="#ref-3">3</a></sup>.

<div style="text-align: center">⁂</div>

> **References**  
> <sup><a id="ref-1" href="https://www.port.io/glossary/domain-driven-design">1</a></sup> [Domain-Driven Design Glossary](https://www.port.io/glossary/domain-driven-design)  
> <sup><a id="ref-2" href="https://appdevcon.nl/the-pros-and-cons-of-domain-driven-design/">2</a></sup> [The Pros and Cons of Domain-Driven Design](https://appdevcon.nl/the-pros-and-cons-of-domain-driven-design/)  
> <sup><a id="ref-3" href="https://positiwise.com/blog/domain-driven-design-core-principles-and-challenges">3</a></sup> [Domain-Driven Design: Core Principles](https://positiwise.com/blog/domain-driven-design-core-principles-and-challenges)  
> <sup><a id="ref-4" href="https://itequia.com/en/domain-driven-design-what-is-it-and-how-to-apply-it-in-my-organization/">4</a></sup> [Domain-Driven Design: how to apply it in my organization?](https://itequia.com/en/domain-driven-design-what-is-it-and-how-to-apply-it-in-my-organization/)

</section>

<section class="doc examples">
  <h2 class="text-3xl font-bold mb-6 text-transparent bg-clip-text bg-gradient-to-r from-yellow-200 to-pink-900">
    Examples
  </h2>
  <div class="space-y-4 text-lg text-white/90">
    <p>
      You can check the <a href="/todo-app-ts/"
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
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2025-07-13 2.0.0 (beta version)</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Moved core to "tilia" npm package.</li>
        <li>Changed <code class="text-yellow-300">make</code> signature to build tilia context.</li>
        <li>Enable forest mode to observe across separated objects.</li>
        <li>Add <code class="text-yellow-300">computed</code> to compute values in branches.</li>
        <li>Moved <code class="text-yellow-300">observe</code> into tilia context.</li>
        <li>Added <code class="text-yellow-300">signal</code>, and <code class='text-yellow-300'>source</code> for FRP style programming.
        </li>
        <li>Added <code class="text-yellow-300">carve</code> for derivation.</li>
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
