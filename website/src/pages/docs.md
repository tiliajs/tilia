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

<div class="text-center mt-4">
  <a href="/guide-fr" class="text-white/70 hover:text-white/90 underline text-sm">📖 Lire en français</a>
</div>

</section>

<a id="installation"></a>

<section class="doc installation">

#### This documentation is for the upcoming version **4.0**

If you need the documentation for previous versions, please send me an email at
(g dot a dot midasum dot com) and I will update the website to display previous
versions API ☺️


## Installation

```bash
# Version 4.0: Code is stable API might change.

npm install tilia@beta 

# With React
npm install @tilia/react
```

</section>

<a id="goals"></a>

<section class="doc goals">

## Goals and Non-goals

<strong class="goal-text">The goal</strong> of Tilia is to provide a minimal and fast state management solution that supports domain-oriented development (such as Clean Architecture or Diagonal Architecture). Tilia is designed so that your code looks and behaves like business logic, rather than being cluttered with library-specific details.

<strong class="non-goal-text">Non-goal</strong> Tilia is not a framework.

</section>

## Fundamental Concepts {.api}

<a id="frp"></a>

<section class="doc frp wide-comment">

### What is Functional Reactive Programming (FRP)?

**Functional Reactive Programming** (FRP) is a programming paradigm that combines two powerful approaches:

1. **Functional programming**: data manipulation via pure functions, without side effects
2. **Reactive programming**: automatic propagation of changes throughout the system

#### The problem FRP solves

In a traditional application, when data changes, you must manually update all parts of the application that depend on it. This leads to complex, fragile, and hard-to-maintain code:

```typescript
// ❌ Traditional imperative approach
let count = 0;
let double = count * 2;
let quadruple = double * 2;

count = 5;
// Oops! double and quadruple are now obsolete
// Need to recalculate them manually...
double = count * 2;
quadruple = double * 2;
```

```rescript
// ❌ Traditional imperative approach
let count = ref(0)
let double = ref(count.contents * 2)
let quadruple = ref(double.contents * 2)

count.contents = 5
// Oops! double and quadruple are now obsolete
// Need to recalculate them manually...
double.contents = count.contents * 2
quadruple.contents = double.contents * 2
```

With FRP, dependencies are declared once and updates propagate automatically:

```typescript
// ✅ Reactive approach with Tilia
import { tilia, computed, observe } from "tilia";

const state = tilia({
  count: 0,
  double: computed(() => state.count * 2),
  quadruple: computed(() => state.double * 2),
});

observe(() => {
  console.log(`count=${state.count}, double=${state.double}, quadruple=${state.quadruple}`);
});

state.count = 5;
// ✨ Automatically: double=10, quadruple=20
// The observe() callback is called with the new values
```

```rescript
// ✅ Reactive approach with Tilia
open Tilia

let state = tilia({
  count: 0,
  double: computed(() => state.count * 2),
  quadruple: computed(() => state.double * 2),
})

observe(() => {
  Js.log(`count=${Int.toString(state.count)}, double=${Int.toString(state.double)}, quadruple=${Int.toString(state.quadruple)}`)
})

state.count = 5
// ✨ Automatically: double=10, quadruple=20
// The observe() callback is called with the new values
```

#### The two reactivity models

Tilia intelligently combines two complementary reactivity models:

**PUSH Reactivity (observe, watch)**

The **push** model means that changes "push" notifications to observers. When a value changes, all callbacks that depend on it are automatically re-executed.

```typescript
observe(() => {
  // This callback will be called every time alice.age changes
  console.log("Alice is", alice.age, "years old");
});

alice.age = 11; // ✨ Automatically triggers the callback
```

```rescript
observe(() => {
  // This callback will be called every time alice.age changes
  Js.log2("Alice is", `${Int.toString(alice.age)} years old`)
})

alice.age = 11 // ✨ Automatically triggers the callback
```

**Use cases**: Side effects (logs, DOM updates, API calls), state synchronization.

**PULL Reactivity (computed)**

The **pull** model means that values are computed lazily, only when they are read. The value is then cached until one of its dependencies changes.

```typescript
const state = tilia({
  items: [1, 2, 3, 4, 5],
  // Computed only when 'total' is read
  total: computed(() => state.items.reduce((a, b) => a + b, 0)),
});

// First read: calculation performed, result cached
console.log(state.total); // 15

// Second read: value returned from cache (no recalculation)
console.log(state.total); // 15

state.items.push(6); // Invalidates the cache

// Read after modification: recalculation
console.log(state.total); // 21
```

```rescript
let state = tilia({
  items: [1, 2, 3, 4, 5],
  // Computed only when 'total' is read
  total: computed(() => Array.reduce(state.items, 0, (a, b) => a + b)),
})

// First read: calculation performed, result cached
Js.log(state.total) // 15

// Second read: value returned from cache (no recalculation)
Js.log(state.total) // 15

state.items = Array.concat(state.items, [6]) // Invalidates the cache

// Read after modification: recalculation
Js.log(state.total) // 21
```

**Use cases**: Derived values, data transformations, filters, aggregations.

#### Why combine both?

| Model    | Advantage                       | Disadvantage                                           |
| -------- | ------------------------------- | ------------------------------------------------------ |
| **Push** | Immediate reaction to changes   | May recalculate unnecessarily if the value is not used |
| **Pull** | Calculation only when necessary | Requires a read to trigger the calculation             |

Tilia allows you to choose the appropriate model based on context, optimizing performance while keeping code expressive.

</section>

<a id="observer-pattern"></a>

<section class="doc observe wide-comment">

### The Observer Pattern

#### The classic pattern

The **Observer pattern** (or Publish-Subscribe) is a behavioral design pattern where an object, called **Subject**, maintains a list of **Observers** and automatically notifies them of any state change.

```
┌─────────────────┐           ┌─────────────────┐
│     Subject     │──notify──▶│    Observer 1   │
│  (source of     │           ├─────────────────┤
│   truth)        │──notify──▶│    Observer 2   │
│                 │           ├─────────────────┤
│                 │──notify──▶│    Observer 3   │
└─────────────────┘           └─────────────────┘
```

In the classic implementation, the observer must explicitly subscribe and unsubscribe:

```typescript
// Classic Observer pattern
subject.subscribe(observer);    // Manual subscription
// ... later
subject.unsubscribe(observer);  // Manual unsubscription (source of bugs!)
```

```rescript
// Classic Observer pattern
subject->subscribe(observer)    // Manual subscription
// ... later
subject->unsubscribe(observer)  // Manual unsubscription (source of bugs!)
```

#### Tilia's approach: automatic tracking

Tilia revolutionizes this pattern by **automatically detecting** which properties are observed. No need to manually subscribe or unsubscribe!

```typescript
import { tilia, observe } from "tilia";

const alice = tilia({
  name: "Alice",
  age: 10,
  city: "Paris",
});

observe(() => {
  // Tilia detects that only 'name' and 'age' are read
  console.log(`${alice.name} is ${alice.age} years old`);
});

alice.age = 11;     // ✨ Triggers the callback (age is observed)
alice.city = "Lyon"; // 😴 Does NOT trigger the callback (city is not observed)
```

```rescript
open Tilia

let alice = tilia({
  name: "Alice",
  age: 10,
  city: "Paris",
})

observe(() => {
  // Tilia detects that only 'name' and 'age' are read
  Js.log2(`${alice.name} is`, `${Int.toString(alice.age)} years old`)
})

alice.age = 11     // ✨ Triggers the callback (age is observed)
alice.city = "Lyon" // 😴 Does NOT trigger the callback (city is not observed)
```

#### Dynamic tracking: only the last execution matters

A crucial point to understand: Tilia doesn't look statically at which properties **could** be read in your function. It only records properties that were **actually read during the last execution** of the callback.

This means that if your callback contains an `if` condition, dependencies change based on the executed branch:

```typescript
import { tilia, observe } from "tilia";

const state = tilia({
  showDetails: false,
  name: "Alice",
  email: "alice@example.com",
  phone: "01 23 45 67 89",
});

observe(() => {
  // 'name' is ALWAYS read
  console.log("Name:", state.name);
  
  if (state.showDetails) {
    // 'email' and 'phone' are tracked only if show details is true
    console.log("Email:", state.email);
    console.log("Phone:", state.phone);
  }
});

// Initial state: showDetails = false
// Current dependencies: { name, showDetails }

state.email = "new@email.com";
// 😴 No notification! 'email' was not read during the last execution

state.showDetails = true;
// ✨ Notification! showDetails is observed
// The callback re-executes, this time reading email and phone
// New dependencies: { name, showDetails, email, phone }

state.email = "another@email.com";
// ✨ Notification! Now email IS observed
```

```rescript
open Tilia

let state = tilia({
  showDetails: false,
  name: "Alice",
  email: "alice@example.com",
  phone: "01 23 45 67 89",
})

observe(() => {
  // 'name' is ALWAYS read
  Js.log2("Name:", state.name)
  
  if state.showDetails {
    // 'email' and 'phone' are read ONLY if showDetails === true
    Js.log2("Email:", state.email)
    Js.log2("Phone:", state.phone)
  }
})

// Initial state: showDetails = false
// Current dependencies: { name, showDetails }

state.email = "new@email.com"
// 😴 No notification! 'email' was not read during the last execution

state.showDetails = true
// ✨ Notification! showDetails is observed
// The callback re-executes, this time reading email and phone
// New dependencies: { name, showDetails, email, phone }

state.email = "another@email.com"
// ✨ Notification! Now email IS observed
```

This dynamic behavior is extremely powerful: your callbacks are never notified for values they don't actually use, which automatically optimizes performance.

</section>

<a id="dependency-graph"></a>

<section class="doc computed wide-comment">

### How Tilia Builds the Dependency Graph

#### JavaScript's Proxy API

Tilia uses JavaScript's [Proxy API](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Proxy) to intercept property access on objects. A Proxy is a transparent wrapper that allows defining custom behaviors for fundamental operations (read, write, etc.).

```typescript
// Simplified Proxy principle
const handler = {
  get(target, property) {
    console.log(`Reading ${property}`);
    return target[property];
  },
  set(target, property, value) {
    console.log(`Writing ${property} = ${value}`);
    target[property] = value;
    return true;
  }
};

const obj = { name: "Alice" };
const proxy = new Proxy(obj, handler);

proxy.name;        // Log: "Reading name"
proxy.name = "Bob"; // Log: "Writing name = Bob"
```

#### The tracking mechanism

When you call `tilia({...})`, the object is wrapped in a Proxy with two essential "traps" (interceptions):

**1. The GET trap (read)**

When a property is read **during the execution of an observation callback**, Tilia records this property as a dependency:

```typescript
// Simplified internal state of Tilia
let currentObserver = null;  // The observer currently executing
const dependencies = new Map();  // Map: observer -> Set of dependencies

const handler = {
  get(target, key) {
    if (currentObserver !== null) {
      // 📝 Recording the dependency
      // "This observer depends on this property"
      addDependency(currentObserver, target, key);
    }
    return target[key];
  },
  // ...
};
```

**2. The SET trap (write)**

When a property is modified, Tilia finds all observers that depend on it and notifies them:

```typescript
const handler = {
  // ...
  set(target, key, value) {
    const oldValue = target[key];
    target[key] = value;
    
    if (oldValue !== value) {
      // 📢 Notification of observers
      // "This property changed, notify all those who depend on it"
      notifyObservers(target, key);
    }
    return true;
  }
};
```

#### Dynamic graph

A crucial point: the dependency graph is **dynamic**. It is rebuilt on each callback execution, which allows handling conditions:

```typescript
const state = tilia({
  showDetails: false,
  name: "Alice",
  email: "alice@example.com",
});

observe(() => {
  console.log("Name:", state.name);
  
  if (state.showDetails) {
    // 'email' is observed ONLY if showDetails is true
    console.log("Email:", state.email);
  }
});

// Current dependencies: {name, showDetails}

state.email = "new@email.com";  // 😴 No notification (email not observed)

state.showDetails = true;       // ✨ Notification + re-execution
// Now dependencies include: {name, showDetails, email}

state.email = "another@email.com"; // ✨ Notification (email is now observed)
```

</section>

<a id="ddd"></a>

<section class="doc ddd wide-comment">

### Carve and Domain-Driven Design

#### The accidental complexity problem

In many state management libraries, business code ends up polluted with technical concepts. Developers must constantly juggle between domain logic and reactive mechanisms:

```typescript
// ❌ Code polluted with FRP concepts
const personStore = createStore({
  firstName: signal("Alice"),
  lastName: signal("Dupont"),
  fullName: computed(() => 
    personStore.firstName.get() + " " + personStore.lastName.get()
  ),
});

// To read a value, you must "think FRP"
const name = personStore.firstName.get();  // .get() ? .value ? ()  ?
personStore.lastName.set("Martin");        // .set() ? .update() ?
```

This code exposes the **reactive plumbing** instead of the **business domain**. A business expert reading this code would see `.get()`, `.set()`, `signal()` instead of simply seeing "a person with a name".

#### Tilia's approach: domain first

With Tilia, you manipulate your business objects like ordinary JavaScript objects. Reactivity is **invisible**:

```typescript
// ✅ Domain-oriented code
const person = tilia({
  firstName: "Alice",
  lastName: "Dupont",
  fullName: computed(() => `${person.firstName} ${person.lastName}`),
});

// Natural reading, like a normal object
console.log(person.firstName);     // "Alice"
console.log(person.fullName); // "Alice Dupont"

// Natural modification
person.lastName = "Martin";
console.log(person.fullName); // "Alice Martin" ✨ Automatic
```

```rescript
// ✅ Domain-oriented code
open Tilia

let person = tilia({
  firstName: "Alice",
  lastName: "Dupont",
  fullName: computed(() => `${person.firstName} ${person.lastName}`),
})

// Natural reading, like a normal object
Js.log(person.firstName)     // "Alice"
Js.log(person.fullName) // "Alice Dupont"

// Natural modification
person.lastName = "Martin"
Js.log(person.fullName) // "Alice Martin" ✨ Automatic
```

Here, `person.firstName` reads exactly like in any JavaScript code. No `.get()`, no `.value`, no function to call. It's simply an object with properties.

#### Ubiquitous Language

**Domain-Driven Design** (DDD) emphasizes the importance of a shared vocabulary between developers and business experts. This vocabulary, called "ubiquitous language", should appear directly in the code.

Tilia facilitates this approach by allowing you to write code that **resembles the domain**:

```typescript
// The code speaks the same language as the business
const cart = tilia({
  items: [],
  promoCode: null,
  
  subtotal: computed(() => 
    cart.items.reduce((sum, a) => sum + a.price * a.quantity, 0)
  ),
  
  discount: computed(() => 
    cart.promoCode?.percentage 
      ? cart.subtotal * cart.promoCode.percentage / 100 
      : 0
  ),
  
  total: computed(() => cart.subtotal - cart.discount),
});

// A business expert can read and understand this code
if (cart.total > 100) {
  applyFreeShipping();
}
```

No trace of FRP in this code. We talk about `cart`, `items`, `total` - exactly the same terms an e-commerce manager would use.

#### Bounded Contexts and modularity

In DDD, a **Bounded Context** is a conceptual boundary where a particular model is defined and applicable. Tilia and `carve` naturally allow creating these boundaries:

```typescript
// "Catalog" context
const catalog = carve<CatalogContext>(({ derived }) => ({
  products: [],
  categories: [],
  search: derived((self) => (term: string) => { /* ... */ }),
  filterByCategory: derived((self) => (cat: string) => { /* ... */ }),
}));

// "Cart" context - different model, same product
const cart = carve<CartContext>(({ derived }) => ({
  lines: [],  // Not "products" - different vocabulary in this context
  add: derived((self) => (product: Product, quantity: number) => { /* ... */ }),
  total: derived((self) => /* ... */),
}));
```

Each context uses its own vocabulary, its own rules, while remaining reactive.

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
// 😴 This does not trigger the effect
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
// 😴 This does not trigger the effect
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

The see different uses of `source`, `store` and `computed`, you can have a look
at the [todo app](/todo-app-ts).

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

<a id="carve"></a>

## <span>✨</span> Carving <span>✨</span> {.carve}

<section class="doc computed wide-comment carve">

### carve

This is where Tilia truly shines. It lets you build a domain-driven, self-contained feature that is easy to test and reuse.

```typescript
const feature = carve(({ derived }) => { ... fields })
```

```rescript
let feature = carve(({derived}) => { ... fields })
```

The `derived` function in the carve argument is like a `computed` but with the
object itself as first parameter.

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

// Injecting the dependency "repo"
const makeTodos = (repo: Repo) => {
  // ✨ Carve the todos feature ✨
  return carve({ derived }) => ({
    sort: "by date",
    list: derived(list),
    data: source([], repo.fetchTodos),
    toggle: derived(toggle),
    repo,
  });
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

// Injecting the dependency "repo"
let makeTodos = repo =>
  // ✨ Carve the todos feature ✨
  carve(({ derived }) => {
    sort: ByDate,
    list: derived(list),
    data: source([], repo.fetchTodos),
    toggle: derived(toggle),
  })
```

**💡 Pro tip:** Carving is a powerful way to build domain-driven, self-contained features. Extracting logic into pure functions (like `list` and `toggle`) makes testing and reuse easy. {.pro}

#### Recursive derivation (state machines)

For recursive derivation (such as state machines), use `source`:

```typescript
derived((tree) => source(initialValue, machine));
```

```rescript
derived(tree => source(initialValue, machine))
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
npm install @tilia/react
```

Insert `useTilia` at the top of the React components that consume tilia values.

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

The App component will now re-render when `alice.age` changes because "age" was read from "alice" during the last render.

</section>

<section class="doc react useTilia">

### leaf <small>(React Higher Order Component)</small> {.leaf}

This is the **favored** way of making reactive components. Compared to
`useTilia`, this tracking is exact due to proper begin/end tracking of the
render phase which is not doable with hooks.

#### Installation

```bash
npm install @tilia/react
```

Wrap your component with `leaf`:

```typescript
import { leaf } from "@tilia/react";

// Use a named function to have proper component names in React dev tools.
const App = leaf(() => {
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
  useTilia()

  if (alice.age >= 13) {
    <SocialMedia />
  } else {
    <NormalApp />
  }
})
```

The App component will now re-render when `alice.age` changes because "age" was read from "alice" during the last render.

</section>

<a id="useComputed"></a>

<section class="doc react useComputed">

### useComputed <small>(React Hook)</small> {.useComputed}

`useComputed` lets you compute a value and only re-render if the result changes.

```typescript
import { useTilia, useComputed } from "@tilia/react";

const TodoView = ({ todo }: { todo: Todo }) => {
  useTilia();

  const selected = useComputed(() => app.todos.selected.id === todo.id);

  return <div className={selected.value ? "text-pink-200" : ""}>...</div>;
};
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
│  cache = EMPTY, valid = false                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (first read)
┌─────────────────────────────────────────────────────────────┐
│                    EXECUTION                                │
│  1. currentObserver = this computed                         │
│  2. Execution of the function                               │
│  3. Dependencies recorded during execution                  │
│  4. cache = result, valid = true                            │
│  5. currentObserver = null                                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (subsequent reads)
┌─────────────────────────────────────────────────────────────┐
│                    CACHE HIT                                │
│  valid = true → return cache directly                       │
│  No recalculation                                           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (dependency changes)
┌─────────────────────────────────────────────────────────────┐
│                    INVALIDATION                             │
│  1. SET detected on a dependency                            │
│  2. valid = false                                           │
│  3. Notification propagated to observers                    │
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

### The "Glue Zone" and Security (v4)

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

#### Safety Proxies (v4)

In v4, computation definitions (`computed`, `source`, `store`) are wrapped in a Safety Proxy:

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

<section class="doc batch wide-comment">

### Flush Strategy and Batching

#### Two behaviors depending on context

When Tilia notifies observers depends on **where** the modification occurs:

| Context                        | Behavior            | Example                                               |
| ------------------------------ | ------------------- | ----------------------------------------------------- |
| **Outside observation**        | **Immediate** flush | Code in an event handler, setTimeout, etc.            |
| **Inside observation context** | **Deferred** flush  | In `computed`, `observe`, `watch`, `leaf`, `useTilia` |

#### Outside observation context: immediate flush

When you modify a value **outside** an observation context, each modification triggers **immediately** a notification:

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
  items: [] as number[],
  
  // ❌ DANGER: the computed reads AND modifies 'items'
  count: computed(() => {
    const len = state.items.length;  // Read 'items'
    state.items.push(len);           // Write to 'items' → invalidates the computed!
    return len;                      // → Recalculate → Read → Write → ∞
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
  () => state.count,              // Observation: tracked
  (count) => {
    state.history.push(count);    // Mutation: no tracking here
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
