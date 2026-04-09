---
layout: ../components/Layout.astro
title: Tilia Documentation - Complete API Reference & Guide
description: Complete documentation for Tilia state management library. Learn tilia, carve, observe, watch, signal, batch, computed, derived, lift, source, store functions and React integration with useTilia, and useComputed hooks.
keywords: tilia documentation, API reference, tila, carve, domain-driven design, ddd, observe, watch, signal, computed, derived, lift, source, store, useTilia, useComputed, React hook, state management guide, TypeScript tutorial, ReScript tutorial, pull reactivity, push reactivity
---

<main class="container mx-auto px-6 py-8 max-w-4xl">
<section class="header">

# Documentation {.documentation}

Complete guide to using Tilia for simple and fast state management in TypeScript and ReScript applications. {.subtitle}

</section>

<a id="installation"></a>

<section class="doc installation">

### This documentation is for version **5.x** and **4.x**

Branches **5.x** and **4.x** have the same API.

For TypeScript, you should use the latest version.

For ReScript 11, use version 4.

## Installation

```shell
npm install tilia
# If you are using tilia with React
npm install @tilia/react
```

</section>

<a id="llm-entry"></a>

<section class="doc llms">

## For LLMs / AI coding assistants

Tilia was built to help your projects grow while staying maintainable and readable wether you prefer typin' o vibin'. 

```md
Use the official Tilia LLM docs index:
- https://tiliajs.com/llms.txt

It links to:
- ReScript patterns
- TypeScript patterns
- carve to build self-contained features
- derived to build reactivity from pure functions
```

You can also directly copy [llms-rescript.md](/llms-rescript.md) or [llms-typescript.md](/llms-typescript.md) into your project or workspace rules (**Knowledge** tab on Lovable for example).

</section>

<a id="goals"></a>

<section class="doc goals">

## Goals and Non-goals

<strong class="goal-text">The goal</strong> of Tilia is to provide a minimal and fast state management solution that supports domain-oriented development (such as Clean Architecture or Diagonal Architecture). Tilia is designed so that your code looks and behaves like business logic, rather than being cluttered with library-specific details.

Since this documentation is about the **glue** to make the code alive, it can feel that you will end up with a lot of library logic in your code. This is absolutely not the case. Tilia helps you build entire applications with **pure functions** and **lean views**.

<strong class="non-goal-text">Non-goal</strong> Tilia is not a framework.

</section>

<a id="ddd"></a>

## The main idea {.api}

<section class="doc ddd">

When building an application, it helps to think in terms of features. We talk with clients, business analysts, and end users and come up with a **need**.

By building an application into separate features (and roles), we help make it maintainable both by humans and AI.

The rule I use for building apps is to separate into three "categories":

* **repo** The persistence layer. In this folder, there is one "carved" object for each data type that is saved.
* **features** The business logic. Here, every feature gets it's own "carved" object.

In both of these, technical "connectors" to the outside world (such as translations, WebAudio, Supabase wrappers) are written into a `service` file that is injected into the feature (or repo).

Here is real world example of a settings feature for [lea.monster](https://lea.monster) (a training focus app built with tilia).

```typescript
// feature/settings/index.ts
import { loader, update } from "./actions";

export const settingsBranch = (service: SettingsService, auth: AuthState) =>
  carve<SettingsRepo>(({ derived }) => ({
    userId: computed(() => auth.userId),
    data: source({ ...DEFAULT_PREFERENCES }, derived(loader(service))),
    update: derived(update(service)),
  }));
```

```rescript
// feature/settings/index.ts
// Please switch to typescript for the example.
```

```typescript
// feature/settings/actions.ts
import type { SettingsService } from "./service";
import type { SettingsRepo, UserPreferences } from "./type";
import { DEFAULT_PREFERENCES } from "./type";

export const loader =
  (service: SettingsService) =>
  (self: SettingsRepo) =>
  (_previous: UserPreferences, set: (v: UserPreferences) => void): void => {
    // self === settingsBranch
    // Observes self.userId
    const uid = self.userId;
    if (!uid) { set({ ...DEFAULT_PREFERENCES }); return; }
    service.load(uid).then(set);
  };

export const update =
  (service: SettingsService) =>
  (self: SettingsRepo) =>
  (fields: Partial<UserPreferences>): void => {
    const uid = self.userId;
    if (!uid) return;
    const prev = self.data;
    self.data = { ...self.data, ...fields };
    service.update(uid, fields).catch(() => {
      self.data = prev;
    });
  };
```

```rescript
// feature/settings/actions.ts
// Please switch to typescript for the example.
```

All the advice I gave the AI on how to use tilia for state management are in the [llms.txt](/llms.txt) documentation.

## API Reference {.api}

<a id="carve"></a>

## <span>✨</span> Carving <span>✨</span> {.carve}

<section class="doc computed wide-comment carve">

### carve

This is where Tilia truly shines. It lets you build a domain-driven, self-contained feature that is easy to test and reuse.

Define your logic as pure functions:

```typescript
const total = (self: Basket) => 
  self.items.reduce(
    (sum, item) => sum + item.price * item.quantity, 0)
```

```rescript
let total = self => 
  self.items
    ->Array.reduce(0, (sum, item) => sum + item.price * item.quantity)
```

Build your featuree as a single, reactive object.

```typescript
const basket = carve<Basket>(({ derived }) => ({
   ...fields,
   total: derived(total)
}))
```

```rescript
let feature = carve(({derived}) => {
  ...fields,
  total: derived(total)
})
```

### Example

```typescript
import { carve, source } from "tilia";

// A pure function for sorting todos, easy to test in isolation.
const list = (todos: Todos) => {
  const compare = todos.sort === "by date"
    ? (a, b) => a.createdAt.localeCompare(b.createdAt)
    : (a, b) => a.title.localeCompare(b.title);
  return [...todos.data].sort(compare);
};

// A pure function for toggling a todo, also easily testable.
const toggle = ({ data, repo }: Todos) => (id: string) => {
  const todo = data.find(t => t.id === id);
  if (todo) {
    todo.completed = !todo.completed;
    repo.save(todo)
  } else {
    throw new Error(`Todo ${id} not found`);
  }
};

// Inject the dependency "repo"
const makeTodos = (repo: Repo) => {
  // ✨ Carve the todos feature ✨
  return carve(({ derived }) => ({
    // state
    sort: "by date",
    // computed state
    list: derived(list),
    // actions
    toggle: derived(toggle),
    // private
    data: source([], repo.fetchTodos),
  }));
};
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

// Inject the dependency "repo"
let makeTodos = repo =>
  // ✨ Carve the todos feature ✨
  carve(({ derived }) => {
    // state
    sort: ByDate,
    // computed state
    list: derived(list),
    // actions
    toggle: derived(toggle),
    // private
    data: source([], repo.fetchTodos),
  })
```

**💡 Pro tip:** Carving is a powerful way to build domain-driven, self-contained features. Extracting logic into pure functions (like `list` and `toggle`) makes testing and reuse easy. {.pro}

#### Recursive derivation (state machines)

For recursive derivation (such as state machines), use `source` inside `carve`:

```typescript
const stateMachine = 
  (self) => source(initialValue, machine(self));
```

```rescript
let stateMachine = 
  self => source(initialValue, machine(self))
```

This allows you to create dynamic or self-referential state that reacts to
changes in other parts of the tree.

For conditional loaders derived from the carved object itself, see
[Derived loader inside source](#source-derived-loader).

<div class="text-center text-3xl text-black hue-rotate-230">💡</div>

#### Difference from `computed`

- Use `computed` for pure derived values that do **not** depend on the entire object.
- Use `derived` (via `carve`) when you need access to the full reactive object
  for cross-property logic or methods.

Look at <a href="https://github.com/tiliajs/tilia/blob/main/todo-app-ts/src/domain/feature/todos/todos.ts">todos.ts</a> for an example of using `carve` to build the todos feature.

</section>

<a id="tilia"></a>

<section class="doc tilia">

### tilia

Transform an object or array into a reactive object. Use this when you want a "quick and dirty" reactive object and you are not designing a feature.

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

During the callback's execution, Tilia tracks which properties are accessed in
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
  Js.log2("Alice is now", `${Int.toString(alice.age)} years old !!`)
})

alice.age = 11; // ✨ This triggers the observe callback
```

**📖 Important Note:** If you mutate an observed tilia value during the observe
call, the callback will be re-run as soon as it ends. {.note}

Now every time alice's age changes, the callback will be called. {.story}

</section>

<a id="watch"></a>

<section class="doc watch wide-comment">

### watch

Use watch similarly to `observe`, but with a clear separation between the
capture phase and the effect phase. The **capture function** observes values,
and the **effect function** is called when the captured values change.

```typescript
import { watch } from "tilia";

watch(
  () => exercise.result,
  (r) => {
    if (r === "Pass") {
      // The effect runs only when `exercise.result` changes, not when
      // `alice.score` changes because the latter is not captured.
      alice.score = alice.score + 1;
    } else if (r === "Fail") {
      alice.score = alice.score - 1;
    }
  }
);

// ✨ This triggers the effect
exercise.result = "Pass";
// This does not trigger the effect 💤
alice.score = alice.score + 10;
```

```rescript
open Tilia

watch(
  () => exercise.result,
  r => switch r {
      // The effect runs only when `exercise.result` changes, not when
      // `alice.score` changes because the latter is not captured.
    | Pass => alice.score = alice.score + 1
    | Fail => alice.score = alice.score - 1
    | Pending => ()
  }
)

// ✨ This triggers the effect
exercise.result = "Pass";
// This does not trigger the effect 💤
alice.score = alice.score + 10;
```

**📖 Note:** If you mutate an observed tilia value in the capture or effect
function, the callback will **not** be re-run and this change will be ignored. {.note}

Now every time alice finishes an exercise, her score updates. {.story}

</section>

<a id="batch"></a>

<section class="doc batch wide-comment">

### batch

Group multiple updates to prevent redundant notifications. This can be required
for managing complex update cycles—such as in games—where atomic state changes
are essential.

**💡 Pro tip** `batch` is not required in `computed`, `source`, `store`,
`observe` or `watch` where notifications are already blocked. {.pro}

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

network->subscribe((updates) => {
  batch(() => {
    Array.forEach(updates, (update) => {
      app->process(update)
    })
  })
  // ✨ Notifications happen here
})
```

</section>

## Functional Reactive Programming {.frp}

✨ **Rainbow architect**, tilia has <span>7</span> more functions for you! ✨ {.rainbow}

Before introducing each one, let us show you an overview. {.subtitle}

<a id="patterns"></a>

<section class="doc patterns wide-comment summary frp">

| Function                | Use-case                                | Tree param | Previous value | Setter | Return value |
| :---------------------- | :-------------------------------------- | :--------: | :------------: | :----: | ------------ |
| [`computed`](#computed) | Computed value from external sources    |    ❌ No    |      ❌ No      |  ❌ No  | ✅ Yes        |
| [`carve`](#carve)       | Cross-property computation              |   ✅ Yes    |      ❌ No      |  ❌ No  | ✅ Yes        |
| [`source`](#source)     | External/async updates                  |    ❌ No    |     ✅ Yes      | ✅ Yes  | ❌ No         |
| [`store`](#store)       | State machine/init logic                |    ❌ No    |      ❌ No      | ✅ Yes  | ✅ Yes        |
| [`readonly`](#readonly) | Avoid tracking on (large) readonly data |            |                |        |              |

And some syntactic sugar:

<table>
    <thead>
        <tr>
            <th style="align:left">Function</th>
            <th style="text-align:left">Use-case</th>
            <th style="text-align:left">Implementation</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td style="text-align:left"><a href="#signal"><code>signal</code></a></td>
            <td style="text-align:left">Create a mutable value and setter</td>
            <td style="text-align:left">

```typescript
const signal = (v) => {
  const s = tilia({ value: v })
  return [s, (v) => { s.value = v }]
}
```
```rescript
let signal = v => {
  let s = tilia({ value: v })
  (s, v => s.value = v)
}
```

  </td>
        </tr>
        <tr>
            <td style="text-align:left"><a href="#derived"><code>derived</code></a></td>
            <td style="text-align:left">Creates a computed value based on other tilia values</td>
            <td style="text-align:left">

```typescript
const derived = (fn) =>
  signal(computed(fn))
```
```rescript
let derived = fn => 
  signal(computed(fn))
```
            
  </td>
        </tr>
        <tr>
            <td style="text-align:left"><a href="#lift"><code>lift</code></a></td>
            <td style="text-align:left">Unwrap a signal to insert it into a tilia object</td>
            <td style="text-align:left">
            
```typescript
const lift = (s) => 
  computed(() => s.value)
```
```rescript
let lift = s => 
  computed(() => s.value)
```
            
  </td>
        </tr>
    </tbody>
</table>

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

#### Chaining computed values

`computed` values can depend on other `computed` values:

```typescript
const store = tilia({
  items: [
    { price: 100, quantity: 2 },
    { price: 50, quantity: 1 },
  ],
  discount: 0.1,  // 10% discount
  
  subtotal: computed(() => 
    store.items.reduce((sum, item) => sum + item.price * item.quantity, 0)
  ),
  
  discountAmount: computed(() => 
    store.subtotal * store.discount
  ),
  
  total: computed(() => 
    store.subtotal - store.discountAmount
  ),
});

console.log(store.total);  // 225 (250 - 25)

store.discount = 0.2;  // Change discount to 20%
console.log(store.total);  // 200 (250 - 50)
```

```rescript
open Tilia

let store = tilia({
  items: [
    {price: 100.0, quantity: 2},
    {price: 50.0, quantity: 1},
  ],
  discount: 0.1,  // 10% discount
  
  subtotal: computed(() => 
    Array.reduce(store.items, 0.0, (sum, item) => sum +. item.price *. Float.fromInt(item.quantity))
  ),
  
  discountAmount: computed(() => 
    store.subtotal *. store.discount
  ),
  
  total: computed(() => 
    store.subtotal -. store.discountAmount
  ),
})

Js.log(store.total)  // 225.0 (250.0 - 25.0)

store.discount = 0.2  // Change discount to 20%
Js.log(store.total)  // 200.0 (250.0 - 50.0)
```

</section>

<a id="source"></a>

<section class="doc frp wide-comment source">

### source

Return a reactive source to be inserted into a Tilia object.

A source is similar to a computed, but it receives an inital value and a setter
function and does not return a value. The setup callback is called on first
value read and whenever any observed value changes. The initial value is used
before the first set call.

```typescript
const app = tilia({
  // Async data (re-)loader (setup will re-run when alice's age changes.
  social: source(
    { t: "Loading" },
    (_previous, set) => {
      if (alice.age > 13) {
        fetchData(set);
      } else {
        set({ t: "NotAvailable" });
      }
    }
  ),
  // Subscription to async event (online status)
  online: source(false, subscribeOnline),
});
```

```rescript
let app = tilia({
  // Async data (re-)loader (setup will re-run when alice's age changes.
  social: source(
    Loading,
    (_previous, set) => {
      // "social" setup will re-run when alice's age changes
      if (alice.age > 13) {
        fetchData(set)
      } else {
        set(NotAvailable)
      }
    }
  ),
  // Subscription to async event (online status)
  online: source(false, subscribeOnline),
})
```

<a id="source-derived-loader"></a>

#### Derived loader inside source

If you need to load data that depends on other parameters, you can combine `source` with `derived`:

```typescript
const loader = (service: Service) => 
  (self: { projectId: string }) => 
  (previous: Project, set: (value: Project) => void) => {
    // 1. Synchronous read (tracked)
    const id = self.projectId;
    // change the previous data to stale and show this while loading
    set(stale(previous));
    
    // 2. Delegate async work
    service.loadProject(id).then((project) => {
      // fully loaded: show
      set(loaded(project));
    });
  };

const selectProject = (self: ProjectBranch) =>
  (id: string) => (self.projectId = id);

const makeProject = (service: Service) =>
  carve<ProjectBranch>(({ derived }) => ({
    // state
    projectId: "main",
    // computed state
    project: source(empty(), derived(loader(service))),
    // actions
    selectProject: derived(selectProject),
  }));
```

```rescript
let loader = service => self => (previous, set) => {
  // 1. Synchronous read (tracked)
  let id = self.projectId
  // change the previous data to stale and show this while loading
  set(stale(previous))
  
  // 2. Delegate async work
  let _ = service.loadProject(id)->Promise.thenResolve(project => {
    // fully loaded: show
    set(loaded(project))
  })
}

let selectProject = self => id => self.projectId = id

let makeProject = service =>
  carve(({derived}) => {
    // state
    projectId: "main",
    // computed state
    project: source(empty(), derived(loader(service))),
    // actions
    selectProject: derived(selectProject),
  })
```

- `derived(loader)` injects the carved object into `loader`, so the source setup can
  use sibling fields like `self.projectId`.
- This lets the loader react to selection changes and refetch the right project.
- `previous` keeps the last value available while new values are loading, so the UI
  can keep showing stale data (for example greyed out) instead of blinking.

**💡 Pro tip:** Make sure that the `source` callback **is not async**. Tilia tracks reactive reads during synchronous execution only. Read dependencies synchronously, then delegate async work.

</section>

<a id="store"></a>

<section class="doc computed wide-comment store">

### store

Return a computed value, created with a **setter** that will be inserted in a Tilia object.

```typescript
import { computed } from "tilia";

const app = tilia({
  auth: store(loggedOut),
});

const loggedOut = (set: Setter<Auth>): Auth => {
  return {
    t: "LoggedOut",
    login: (user: User) => set(loggedIn(set, user)),
  };
};

const loggedIn = (set: Setter<Auth>, user: User): Auth => {
  return {
    t: "LoggedIn",
    user: User,
    logout: () => set(loggedOut(set)),
  };
};
```

```rescript
open Tilia

let loggedOut = set => LoggedOut({
  login: user => set(loggedIn(set, user)),
})

let loggedIn = (set, user) => LoggedIn({
  user: User,
  logout: () => set(loggedOut(set)),
})

let app = tilia({
  auth: store(loggedOut),
})
```

**💡 Pro tip:** `store` is a very powerful pattern that makes it easy to initialize a feature in a specific state (for testing for example). {.pro}

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

This is a tiny wrapper around `tilia` to expose a single, changing value and a setter.

```typescript
type Signal<T> = { value: T };

const signal = (v) => {
  const s = tilia({ value: v })
  return [s, (v) => { s.value = v }]
}

// Usage

const [s, set] = signal(0)

set(1)
console.log(s.value)
```

```rescript
type signal<'a> = {value: 'a}

let signal = (v: 'a) => {
  let s = tilia({value: v})
  (s, (v: 'a) => s.value = v)
}

// Usage

let (s, set) = signal(0)

set(1)
Js.log(s.value)
```

**🌱 Small tip**: Use `signal` for state computations and expose them with `tilia` and `lift` to reflect your domain:

```typescript
// ✅ Domain-driven
const [authenticated, setAuthenticated] = signal(false)

const app = tilia({
  authenticated: lift(authenticated)
  now: store(runningTime),
});

if (app.authenticated) {
}
```

```rescript
// ✅ Domain-driven
let (authenticated, setAuthenticated) = signal(false)

let app = tilia({
  authenticated: lift(authenticated),
  now: store(runningTime),
})

if app.authenticated {
}
```

</section>

<a id="derived"></a>

<section class="doc frp wide-comment derived">

### derived

Create a signal representing a computed value. This is similar to the `derived`
argument of `carve`, but outside of an object.

```typescript
const derived = <T>(fn: () => T): Signal<T> => {
  return signal(computed(fn));
};

// Usage

const s = signal(0);

const double = derived(() => s.value * 2);
console.log(double.value);
```

```rescript

let derived = fn => signal(computed(fn))

// Usage

let s = signal(0)
let double = derived(() => s.value * 2)
Js.log(double.value)
```

</section>

<a id="lift"></a>

<section class="doc frp wide-comment lift">

### lift

Create a `computed` value that reflects the current value of a signal to be
inserted into a Tilia object. Use signal and lift to create private state
and expose values as read-only.

```typescript
// Lift implementation
const lift = <T>(s: Signal<T>): T => {
  return computed(() => s.value);
};

// Usage
type Todo = {
  readonly title: string;
  setTitle: (title: string) => void;
};

const (title, setTitle) = signal("");

const todo = tilia({
  title: lift(title),
  setTitle,
});
```

```rescript
// Lift implementation
let lift = s => computed(() => s.value)

// Usage
type todo = {
  title: string,
  setTitle: title => unit,
}

let [title, setTitle] = signal("")

let todo = tilia({
  title: lift(title),
  setTitle,
})
```

</section>

<a id="react"></a>

## React Integration {.react}

<a id="leaf"></a>

<section class="doc react leaf">

#### Installation

```bash
npm install @tilia/react
```

### leaf <small>(React Higher Order Component)</small> {.leaf}

This is the **favored** way of making reactive components. Compared to using the
`useTilia` hook, the dependency tracking is exact which is not doable with hooks.

Wrap your component with `leaf`:

```typescript
import { leaf } from "@tilia/react";

const App = leaf(() => {
  // Now tilia tracks read operations and registers the exact 
  // dependencies of the current render.
  if (alice.age >= 13) {
    return <SocialMediaApp />;
  } else {
    return <NormalApp />;
  }
});
```

```rescript
open TiliaReact

@react.component
let make = leaf(() => {
  // Now tilia tracks read operations and registers the exact 
  // dependencies of the current render.
  if (alice.age >= 13) {
    <SocialMedia />
  } else {
    <NormalApp />
  }
})
```

The App component will now re-render when `alice.age` changes because "age" was read from "alice" during the last render and the `leaf` wrapper tracks dependencies.

#### useApp

This is just an advice on architecture and shows `leaf` usage with dependency injection for components (to make components testable).

Create an app context. Because tracking is fine-grained and the global state is mutated in place, this works seamlessly.

```typescript
export type App = {
  // ... compose app type from features
}

export const emptyApp = {
  // default values. Can be used as basis for
  // creating app mock objects during testing.
}

const AppContext = createContext<App>(emptyApp);

export const AppProvider = ({ app, children }: { app: App; children: React.ReactNode }) => 
    <AppContext.Provider value={app}>{children}</AppContext.Provider>;

export const useApp = (): App => useContext(AppContext);
```

```rescript
// App module

let app = {
  // .. compose type
}

let empty: app = {
  // default values. Can be used as basis for
  // creating app mock objects during testing.
}

let context = React.createContext(empty);

let useApp = () => React.useContext(context)

module Provider = {
  let make (~app) => React.Context.provider(app)
}
```

And then, components use the app like this:

```typescript
import { leaf } from "@tilia/react"
import { useApp } from "../App"

export const TodoList = leaf(() => {
  // ❌ AVOID reading all required elements at the top (it
  // defeats the granularity of dependency tracking).
  // const { todos: { list, count } } = useApp()

  // ✅ do this for easy property renaming and readable values
  // in the JSX: `count` can be anything `todos.count` is obvious.
  // Plus it makes cleanup and refactoring easier.
  const { todos } = useApp()

  return <div>{todos.count}</div>
})
```

```rescript
open TiliaReact
open App

@react.component
let make = leaf(() => {
  // ❌ AVOID reading all required elements at the top (it
  // defeats the granularity of dependency tracking).
  // const { todos: { list, count } } = useApp()

  // ✅ do this for easy property renaming and readable values
  // in the JSX: `count` can be anything `todos.count` is obvious.
  // Plus it makes cleanup and refactoring easier.
  let {todos} = useApp()

  <div>{todos.count->Int.toString->React.string}</div>
})
```
</section>

<a id="useTilia"></a>

<section class="doc react useTilia">

### useTilia <small>(React Hook)</small> {.useTilia}

#### Installation

```bash
npm install @tilia/react
```

Insert `useTilia` at the top of the React components that consume tilia values. This offers an easy way to make existing components reactive but it should be avoided because of the extra `useEffect` it requires to close dependency tracking at the end of the render phase. Use `leaf` instead.

```typescript
import { useTilia } from "@tilia/react";

const App = () => {
  useTilia();

  if (alice.age >= 13) {
    return <SocialMediaApp />;
  } else {
    return <NormalApp />;
  }
};
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

</section>

<a id="useComputed"></a>

<section class="doc react useComputed">

### useComputed <small>(React Hook)</small> {.useComputed}

`useComputed` lets you compute a value and only re-render if the result of the value changes (not the dependencies). This is useful for quick view only computations.

```typescript
import { useTilia, useComputed } from "@tilia/react";

const TodoView = ({ todo }: { todo: Todo }) => {
  useTilia();

  const selected = useComputed(() => app.todos.selected.id === todo.id);

  return <div className={selected ? "text-pink-200" : ""}>...</div>;
};
```

```rescript
open TiliaReact

@react.component
let make = () => {
  useTilia()

  let selected = useComputed(() => app.todos.selected.id === todo.id)

  <div className={selected ? "text-pink-200" : ""}>...</div>;
}
```

With this helper, the TodoView does not depend on `app.todos.selected.id` but on `selected`. This prevents the component from re-rendering on every change to the selected todo.

</section>

<a id="technical"></a>

## Deep Technical Reference {.api}

<a id="architecture"></a>

<section class="doc computed wide-comment">

### Internal Architecture

#### Proxy Handler Structure

Here is a simplified representation of the Proxy handler used by Tilia:

```typescript
// Simplified for understanding
const createHandler = (context: TiliaContext) => ({
  get(target: object, key: string | symbol, receiver: unknown) {
    // 1. Ignore symbols and internal properties
    if (typeof key === "symbol" || key.startsWith("_")) {
      return Reflect.get(target, key, receiver);
    }
    
    // 2. Record dependency if an observer is active
    if (context.currentObserver !== null) {
      context.addDependency(context.currentObserver, target, key);
    }
    
    // 3. Retrieve the value
    const value = Reflect.get(target, key, receiver);
    
    // 4. If it's an object, wrap it recursively
    if (isObject(value) && !isProxy(value)) {
      return createProxy(value, context);
    }
    
    // 5. If it's a computed, execute it
    if (isComputed(value)) {
      return executeComputed(value, context);
    }
    
    return value;
  },
  
  set(target: object, key: string | symbol, value: unknown, receiver: unknown) {
    const oldValue = Reflect.get(target, key, receiver);
    
    // 1. Perform the modification
    const result = Reflect.set(target, key, value, receiver);
    
    // 2. Notify if the value changed
    if (!Object.is(oldValue, value)) {
      context.notify(target, key);
    }
    
    return result;
  },
  
  deleteProperty(target: object, key: string | symbol) {
    const result = Reflect.deleteProperty(target, key);
    
    // Notify of the deletion
    if (result) {
      context.notify(target, key);
    }
    
    return result;
  },
  
  ownKeys(target: object) {
    // Track iteration over keys
    if (context.currentObserver !== null) {
      context.addDependency(context.currentObserver, target, KEYS_SYMBOL);
    }
    return Reflect.ownKeys(target);
  },
});
```

#### Lifecycle of a computed

```
┌─────────────────────────────────────────────────────────────┐
│                    INITIAL STATE                            │
│  computed created but not yet executed                      │
│  cache = EMPTY                                              |
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (first read)
┌─────────────────────────────────────────────────────────────┐
│                    EXECUTION                                │
│  1. currentObserver = this computed                         │
│  2. Execution of the function                               │
│  3. Dependencies recorded during execution                  │
│  4. cache = result                                          |
│  5. currentObserver = previous observer                     |
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (subsequent reads)
┌─────────────────────────────────────────────────────────────┐
│                    CACHE HIT                                │
│  cache exists → return cache directly                       │
│  No recalculation                                           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (dependency changes)
┌─────────────────────────────────────────────────────────────┐
│                    INVALIDATION                             │
│  1. SET detected on a dependency                            │
│  2. if observed : value recomputed                          |
│  3. value changed ? → notification propagated to observers  |
│  4. not observed : cache reset                              |
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (next read)
┌─────────────────────────────────────────────────────────────┐
│                    RE-EXECUTION                             │
│  Same process as EXECUTION                                  │
│  Potentially different new dependencies                     │
└─────────────────────────────────────────────────────────────┘
```

#### Forest Mode

Tilia supports "Forest Mode" where multiple separate `tilia()` objects can be observed together:

```typescript
const alice = tilia({ name: "Alice", age: 10 });
const bob = tilia({ name: "Bob", age: 12 });

// A single observe that depends on TWO trees
observe(() => {
  console.log(`${alice.name} is ${alice.age} years old`);
  console.log(`${bob.name} is ${bob.age} years old`);
});

alice.age = 11;  // ✨ Triggers the observe
bob.age = 13;    // ✨ Also triggers the observe
```

This is possible thanks to the shared global context that maintains dependencies for all trees.

</section>

<a id="glue-zone"></a>

<section class="doc errors wide-comment">

### The "Glue Zone" and Security

#### The Orphan Computations Problem

Before v4, it was possible to create a `computed` outside of a Tilia object, which caused obscure errors:

```typescript
// ❌ DANGER: computed created "in the void"
const trouble = computed(() => count.value * 2);

// Later, access outside a reactive context
const crash = trouble * 2;  // 💥 Obscure error!
```

#### The "Glue Zone"

The "Glue Zone" is the dangerous area where a computation definition exists without being attached to an object. In v4, Tilia adds protections to avoid this problem.

```typescript
// BEFORE (Glue Zone - dangerous)
const computed_def = computed(() => x.value * 2);
// 'computed_def' is a "ghost" - neither a value, nor attached to an object

// AFTER (insertion in an object - safe)
const obj = tilia({
  double: computed(() => x.value * 2)  // ✅ Created directly in the object
});
```

#### Safety Proxies

Since v4, computation definitions (`computed`, `source`, `store`) are wrapped in a Safety Proxy:

- **In a reactive context** (tilia/carve): the proxy unwraps transparently
- **Outside**: the proxy **throws a descriptive error**

```typescript
const [count, setCount] = signal(0);

// ❌ Creating an orphan
const orphan = computed(() => count.value * 2);

// 🛡️ v4 Protection: Throws a clear error
const result = orphan * 2;
// Error: "Orphan computation detected. computed/source/store must be
// created directly inside a tilia or carve object."
```

#### Golden rule

> **NEVER** assign the result of a `computed`, `source`, or `store` to an intermediate variable.  
> **ALWAYS** define them directly in a `tilia()` or `carve()` object.

```typescript
// ❌ Bad
const myComputed = computed(() => ...);
const obj = tilia({ value: myComputed });

// ✅ Good
const obj = tilia({
  value: computed(() => ...)
});
```

</section>

<a id="flush-batching"></a>

<section class="doc batch wide-comment summary">

### Flush Strategy and Batching

#### Two behaviors depending on context

When Tilia notifies observers depends on **where** the modification occurs:

| Context                        | Behavior            | Example                                    |
| ------------------------------ | ------------------- | ------------------------------------------ |
| **Outside observation**        | **Immediate** flush | Code in an event handler, setTimeout, etc. |
| **Inside observation context** | **Deferred** flush  | In `derived`, `observe`, `leaf`, etc.      |

#### Outside observation context: immediate flush

When you modify a value **outside** an observation context, each modification triggers an **immediate** notification:

```typescript
const state = tilia({ a: 1, b: 2 });

observe(() => {
  console.log(`a=${state.a}, b=${state.b}`);
});
// Output: "a=1, b=2"

// Outside observation context (e.g., in an event handler)
state.a = 10;
// ⚡ IMMEDIATE notification!
// Output: "a=10, b=2"

state.b = 20;
// ⚡ IMMEDIATE notification!
// Output: "a=10, b=20"
```

#### The problem of inconsistent transient states

This behavior can cause problems when multiple properties must change together coherently:

```typescript
const rect = tilia({
  width: 100,
  height: 50,
  ratio: computed(() => rect.width / rect.height),
});

observe(() => {
  console.log(`Dimensions: ${rect.width}x${rect.height}, ratio: ${rect.ratio}`);
});
// Output: "Dimensions: 100x50, ratio: 2"

// Want to go to 200x100 (same ratio)
rect.width = 200;
// ⚠️ Inconsistent transient state!
// Output: "Dimensions: 200x50, ratio: 4"  ← incorrect ratio!

rect.height = 100;
// Output: "Dimensions: 200x100, ratio: 2"  ← correct now
```

The observer saw an intermediate state where the ratio was 4, which was never the intention.

#### batch(): the solution for grouped modifications

`batch()` allows grouping multiple modifications and notifying only once at the end:

```typescript
import { batch } from "tilia";

// ✅ With batch: a single coherent notification
batch(() => {
  rect.width = 200;
  rect.height = 100;
  // No notification during the batch
});
// ✨ Single notification here
// Output: "Dimensions: 200x100, ratio: 2"
```

**Typical use cases for `batch()`:**
- Event handlers that modify multiple properties
- WebSocket/SSE callbacks with multiple updates
- Initialization of multiple values

#### Inside observation context: automatic deferred flush

Inside a `computed`, `observe`, `watch` callback, or a component with `leaf`/`useTilia`, notifications are **automatically deferred**. No need to use `batch()`:

```typescript
const state = tilia({
  items: [],
  processedCount: 0,
});

observe(() => {
  // Inside an observation context, modifications are batched
  for (const item of incomingItems) {
    state.items.push(item);
    state.processedCount++;
    // No notification here, even if observers are watching these values
  }
  // ✨ Notifications at the end of the callback
});
```

#### Recursive mutations in observe

If you modify a value observed **by the same callback** in `observe`, it will be scheduled for re-execution after the current execution ends:

```typescript
observe(() => {
  console.log("Value:", state.value);
  
  if (state.value < 5) {
    state.value++;  // Schedules a new execution
  }
});

// Output:
// "Value: 0"
// "Value: 1"
// "Value: 2"
// "Value: 3"
// "Value: 4"
// "Value: 5"
```

**⚠️ Attention:** This feature is powerful but can create infinite loops if misused.

</section>

<a id="mutations-computed"></a>

<section class="doc computed wide-comment">

### Mutations in computed: infinite loop risk

The main danger of mutations in a `computed` is the risk of an **infinite loop**: if the `computed` reads the value it modifies, it invalidates itself and loops.

```typescript
const state = tilia({
  items: [],
  
  // ❌ DANGER: the computed reads AND modifies 'items'
  count: computed(() => {
    // Read 'items'
    const len = state.items.length;
    // Write to 'items' → invalidates the computed!
    state.items.push(len);           
    // → Recalculate → Read → Write → ∞
    return len;                      
  }),
});

// Accessing state.count causes an infinite loop!
```

```rescript
let state = tilia({
  items: [],
  
  // ❌ DANGER: the computed reads AND modifies 'items'
  count: computed(() => {
    // Read 'items'
    const len = state.items->Array.length;
    // Write to 'items' → invalidates the computed!
    state.items->Array.push(len);           
    // → Recalculate → Read → Write → ∞
    return len;                      
  }),
});

// Accessing state.count causes an infinite loop!
```

**The problem:** The `computed` observes `items`, then modifies it, which invalidates it and causes a new calculation, which observes again, modifies again, etc.

#### Solution: use `watch` to separate observation and mutation

`watch` clearly separates:
- The **observation phase** (first callback): tracked, defines dependencies
- The **mutation phase** (second callback): without tracking, no loop risk

```typescript
const state = tilia({
  count: 0,
  history: [] as number[],
});

// ✅ GOOD: watch separates observation and mutation
watch(
  // Observation: tracked
  () => state.count,              
  (count) => {
    // Mutation: no tracking here
    state.history.push(count);    
  }
);

state.count = 1;  // history becomes [1]
state.count = 2;  // history becomes [1, 2]
```

```rescript
let state = tilia({
  count: 0,
  history: [],
});

// ✅ GOOD: watch separates observation and mutation
watch(
  // Observation: tracked
  () => state.count,              
  (count) => {
    // Mutation: no tracking here
    state.history.push(count);    
  }
);

state.count = 1;  // history becomes [1]
state.count = 2;  // history becomes [1, 2]
```

With `watch`, the mutation in the second callback is **not tracked**, so it cannot create a loop even if it reads and modifies the same values.

</section>

<a id="garbage-collection"></a>

<section class="doc computed wide-comment">

### Garbage Collection

#### What JavaScript's native GC manages

JavaScript's native garbage collector manages very well the release of **tracked objects** that are no longer used in memory. If a `tilia({...})` object is no longer referenced anywhere, JavaScript automatically releases it, along with all its internal dependencies.

You don't need to do anything for this: it's JavaScript's standard behavior.

#### What Tilia's GC manages

For each observed property, Tilia maintains a **list of watchers**. When a watcher is "cleared" (for example, when a React component unmounts), it is removed from the list, but the list itself (even empty) remains attached to the property.

These empty lists represent very little data, but Tilia cleans them up periodically:

```typescript
import { make } from "tilia";

// GC threshold configuration
const ctx = make({
  gc: 100,  // Triggers cleanup after 100 watchers cleared
});

// The default threshold is 50
```

#### When cleanup triggers

1. A watcher is "cleared" (component unmounted, etc.)
2. The `clearedWatchers` counter increments
3. If `clearedWatchers >= gc`, cleanup of the watcher list
4. `clearedWatchers` resets to 0

#### Configuration based on application

```typescript
// Application with many dynamic components (lists, tabs, modals)
const ctx = make({ gc: 200 });

// More stable application with few mount/unmounts
const ctx = make({ gc: 30 });
```

In practice, the default threshold (50) suits most applications.

</section>

<a id="error-handling"></a>

<section class="doc errors wide-comment">

### Error Handling

#### Errors in computed and observe

When an exception is thrown in a `computed` or `observe` callback, Tilia adopts an **error reporting** strategy to avoid blocking the application:

1. The exception is **caught** immediately
2. The error is **logged** in `console.error` with a cleaned stack trace
3. The faulty observer is **cleaned up** (cleared) to avoid blocking the system
4. The error is **re-thrown** at the end of the next flush

```typescript
const state = tilia({
  value: 0,
  computed: computed(() => {
    if (state.value === 42) {
      throw new Error("The universal answer is forbidden!");
    }
    return state.value * 2;
  }),
});

observe(() => {
  console.log("Computed:", state.computed);
});

// Everything works
state.value = 10;  // Log: "Computed: 20"

// Triggers an error
state.value = 42;
// 1. Error is logged immediately in console.error
// 2. Observer is cleaned up
// 3. Error is re-thrown at the end of the flush
```

#### Why defer the error?

This behavior allows:

1. **Not blocking other observers**: If one observer crashes, others continue to function
2. **Keeping the application stable**: The reactive system is not locked by an error
3. **Logging immediately**: The error appears in the console as soon as it occurs
4. **Propagating the error**: The exception still bubbles up to be handled by the application

#### Cleaned stack trace

To facilitate debugging, Tilia cleans the stack trace by removing internal library lines. You see directly where the error occurred in **your** code:

```
Exception thrown in computed or observe
    at myComputed (src/domain/feature.ts:42:15)
    at handleClick (src/components/Button.tsx:18:5)
```

#### Best practices

```typescript
// ✅ Handle error cases in computed
const state = tilia({
  data: computed(() => {
    try {
      return riskyOperation();
    } catch (e) {
      console.error("Operation failed:", e);
      return { error: true, message: e.message };
    }
  }),
});

// ✅ Use default values
const state = tilia({
  user: computed(() => fetchedUser ?? { name: "Anonymous" }),
});
```

</section>

<div class="flex flex-row space-x-4 justify-center items-center w-full gap-12">
  <a href="/compare"
    class="bg-gradient-to-r from-green-400 to-blue-500 px-6 py-3 rounded-full font-bold hover:scale-105 transform transition">
    Compare with...
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

**Domain-Driven Design (DDD)** is a methodology that centers software around the core business domain, using a shared language between developers and domain experts, and structuring code to reflect real business concepts and processes<sup><a href="#ref-1">1</a></sup><sup><a href="#ref-2">2</a></sup><sup><a href="#ref-3">3</a></sup>. Tilia's design and features directly support these DDD goals in several ways:

- **Ubiquitous Language in Code:**
  Tilia's API encourages you to model your application state using the same terms and structures that exist in your business domain. With minimal boilerplate and no imposed framework-specific terminology, your codebase can closely mirror the language and logic of your domain, making it easier for both developers and domain experts to understand and collaborate<sup><a href="#ref-1">1</a></sup><sup><a href="#ref-2">2</a></sup>.
- **Bounded Contexts and Modularity:**
  Tilia enables you to compose state into clear, isolated modules (using `carve`, for example), which naturally map to DDD's concept of bounded contexts. Each feature or subdomain can be managed independently, reducing complexity and making it easier to evolve or refactor parts of your system as business requirements change<sup><a href="#ref-1">1</a></sup><sup><a href="#ref-3">3</a></sup>.
- **Rich Domain Models:**
  By allowing you to define computed properties, derived state, and domain-specific actions directly within your state objects, Tilia helps you build rich domain models. This keeps business logic close to the data it operates on, improving maintainability and clarity<sup><a href="#ref-1">1</a></sup><sup><a href="#ref-2">2</a></sup>.
- **Continuous Evolution:**
  Tilia's reactive model and compositional API make it easy to refactor and extend your domain models as your understanding of the business evolves. This aligns with DDD's emphasis on evolutionary design and ongoing collaboration with domain experts<sup><a href="#ref-3">3</a></sup>.
- **Improved Communication and Onboarding:**
  Because Tilia encourages code that reads like your business language, new team members and stakeholders can more quickly understand the system. This reduces onboarding time and the risk of miscommunication between technical and non-technical team members<sup><a href="#ref-2">2</a></sup>.
- **Testability and Isolation:**
  Tilia's modular state and clear separation between state, actions, and derived values enable you to test domain logic in isolation, a key DDD best practice<sup><a href="#ref-4">4</a></sup>.

**In summary:**
Tilia's minimal, expressive API and focus on modeling state and logic directly in the language of your business domain make it an excellent fit for domain-driven design. It helps you produce code that is understandable, maintainable, and closely aligned with business needs—while making it easier to manage complexity and adapt to change<sup><a href="#ref-1">1</a></sup><sup><a href="#ref-2">2</a></sup><sup><a href="#ref-3">3</a></sup>.

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

<section class="doc translations">
  <h2 class="text-3xl font-bold mb-6 text-transparent bg-clip-text bg-gradient-to-r from-purple-200 to-cyan-900">
    Complete Guides
  </h2>
  <div class="space-y-4 text-lg text-white/90">
    <p>
      Comprehensive guides with detailed explanations and examples:
    </p>
    <ul class="list-disc list-outside space-y-2 ml-6">
      <li>
        <a href="/guide-fr"
          class="text-blue-300 hover:text-blue-200 underline">Guide complet en français</a> - Guide complet pour comprendre et utiliser Tilia
      </li>
    </ul>
  </div>
</section>

<section class="doc changelog">
  <h2 class="text-3xl font-bold mb-6 text-transparent bg-clip-text bg-gradient-to-r from-red-300 to-teal-900">
    Changelog
  </h2>
  <div class="space-y-6 text-white/90">
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2025-12-18 5.0.0 (beta)</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Update to ReScript v12.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2025-12-18 4.0.0</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Changed <code class="text-yellow-300">@tilia/react</code> dependency to track MAJOR.MINOR version of tilia.</li>
        <li>Add apps to test different project setup.</li>
        <li>Improve error reporting for "Orphan Computation Error". See <a href="https://tiliajs.com/errors" class="text-blue-300 hover:text-blue-200 underline">https://tiliajs.com/errors</a>.</li>
        <li>Remove explicit 'exports' from package.json to support any suffix in ReScript setup.</li>
        <li>Add previous value to <code class="text-yellow-300">source</code> as first parameter.</li>
        <li>Move parameter order in <code class="text-yellow-300">source</code>, starting with initial value.</li>
        <li>Move <code class="text-yellow-300">source</code> and <code class="text-yellow-300">store</code> into the context and allow computed in source callback (to be used with derived).</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2025-09-09 3.0.0</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Rename <code class="text-yellow-300">unwrap</code> for <code class="text-yellow-300">lift</code>, change syntax for <code class="text-yellow-300">signal</code> to expose setter.</li>
        <li>Protect tilia from exceptions in computed: the exception is caught, logged to <code class="text-yellow-300">console.error</code> and re-thrown at the end of the next flush.</li>
        <li>Add <code class="text-yellow-300">leaf</code> to @tilia/react: a higher order component to close the observing phase at the exact end of the render.</li>
        <li>Simplify <code class="text-yellow-300">useComputed</code> in @tilia/react to return the value directly.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2025-08-08 2.2.0</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Add <code class="text-yellow-300">unwrap</code> to ease inserting a signal into a tilia object.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2025-08-08 2.1.1</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Fix <code class="text-yellow-300">source</code> type: ignore return value for easier async support.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2025-08-03 2.1.0</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Add <code class="text-yellow-300">derived</code> to compute a signal from other tilia values.</li>
        <li>Add <code class="text-yellow-300">watch</code> to separate the capture phase and the effect phase of observe.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2025-07-24 2.0.1</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Fix package.json configuration in @tilia/react publish script.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2025-07-21 2.0.0</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Add tests and examples with Gherkin for todo app.</li>
        <li>Moved core to npm "tilia" package.</li>
        <li>Changed <code class="text-yellow-300">make</code> signature to build tilia context (provides the full API running in a separate context).</li>
        <li>Enable <strong>forest mode</strong> to observe across separated objects.</li>
        <li>Add <code class="text-yellow-300">computed</code> to compute values in branches (moved into <code class="text-yellow-300">tilia</code> context).</li>
        <li>Moved <code class="text-yellow-300">observe</code> into <code class="text-yellow-300">tilia</code> context.</li>
        <li><code class="text-yellow-300">observe</code> <em>will be called</em> for its own mutations (this is to allow state machines).</li>
        <li>Removed re-exports in @tilia/react.</li>
        <li>Removed <code class="text-yellow-300">compute</code> (replaced by <code class="text-yellow-300">computed</code>).</li>
        <li>Removed <code class="text-yellow-300">track</code> as this cannot scale to multiple instances and computed.</li>
        <li>Renamed internal <code class="text-yellow-300">_connect</code> to <code class="text-yellow-300">_observe</code>.</li>
        <li>Reworked API to ensure strong typing and avoid runtime errors.</li>
        <li>Add <code class="text-yellow-300">source</code>, <code class="text-yellow-300">readonly</code> and <code class="text-yellow-300">signal</code> for FRP style programming.</li>
        <li>Add <code class="text-yellow-300">carve</code> to support derivation (build domain features from objects).</li>
        <li>Improved flush strategy to trigger immediately but not in an observing function.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2025-05-05 1.6.0</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Add <code class="text-yellow-300">compute</code> method to cache values on read.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2025-01-17 1.4.0</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Add <code class="text-yellow-300">track</code> method to observe branches.</li>
        <li>Add <code class="text-yellow-300">flush</code> strategy for tracking notification.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2025-01-02 1.3.2</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Fix extension in built artifacts.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2024-12-31 1.3.0</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Expose internals with <code class="text-yellow-300">_meta</code>.</li>
        <li>Rewrite tracking to fix memory leaks when <code class="text-yellow-300">_ready</code> and <code class="text-yellow-300">clear</code> are never called.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2024-12-27 1.2.4</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Add support for ready after clear.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2024-12-24 1.2.3</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Rewrite tracking to fix notify and clear before ready.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2024-12-18 1.2.2</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Fix readonly tracking: should not proxy.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2024-12-18 1.2.1</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Fix bug to not track prototype methods.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2024-12-18 1.2.0</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Improve ownKeys watching, notify on key deletion.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2024-12-18 1.1.1</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Fix build issue (rescript was still required).</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2024-12-17 1.1.0</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Add support to share tracking between branches.</li>
      </ul>
    </div>
    <div>
      <h3 class="text-xl font-bold text-green-200/80 mb-2">2024-12-13 1.0.0</h3>
      <ul class="list-disc list-outside space-y-1 ml-4 text-sm md:text-base">
        <li>Alpha release.</li>
      </ul>
    </div>
  </div>
</section>
</main>
