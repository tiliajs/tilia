---
layout: ../components/Layout.astro
title: Tilia Common Errors - Troubleshooting Guide
description: Common errors and mistakes when using Tilia. Learn how to fix orphan computations, glue zone issues, and other common problems.
keywords: tilia errors, orphan computations, glue zone, troubleshooting, common mistakes, tilia debugging, reactive programming errors
---

<main class="container mx-auto px-6 py-8 max-w-4xl">
<section class="header">

# Common Errors {.documentation}

A guide to common errors and how to fix them when using Tilia. {.subtitle}

</section>

<a id="orphan"></a>

<section class="doc errors wide-comment">

### Orphan Computation Error

If you're seeing this error, it means you tried to use a computation (`computed`, `source`, or `store`) that was created outside of a reactive object.

#### The Error Messages

You may encounter one of these errors:

- **Cannot access value of an orphan computation**
- **Cannot modify an orphan computation**

#### What Are Orphan Computations?

An "orphan computation" is a computation definition that exists in the "void"—it was created outside of any reactive object (`tilia`, `carve`, or `derived`). It is a computation definition that looks like the returned type but is actually an object containing that definition (shadow type pattern).

Think of it this way:
- **Computation definition** = A description of *how* to compute a value
- **Reactive object** = The container that brings that definition to life

Without a reactive object, the computation is just a description floating in memory—it can't actually compute anything.

### The Problem Pattern

```typescript
const [count, setCount] = signal(0)

// ❌ WRONG: Creating an orphan computation
// This creates a computation definition in the void
const trouble = computed(() => count.value * 2)

// ❌ ERROR: Trying to use the orphan computation
// This will throw: "Cannot access value of an orphan computation"
const result = trouble * 2
```

```rescript
let (count, setCount) = signal(0)

// ❌ WRONG: Creating an orphan computation
// This creates a computation definition in the void
let trouble = computed(() => count.value * 2)

// ❌ ERROR: Trying to use the orphan computation
// This will throw: "Cannot access value of an orphan computation"
let result = trouble * 2
```

In this example:
1. `trouble` is assigned a **computation definition** (not a value)
2. When you try to use `trouble` in `trouble * 2`, JavaScript tries to access its value
3. The proxy intercepts this and throws an error because the computation was never attached to a reactive graph

### The Correct Pattern

Define computations **directly inside** reactive objects:

```typescript
const [count, setCount] = signal(0)

// ✅ CORRECT: Define computed directly in a reactive object
const p = tilia({
  double: computed(() => count.value * 2)
})

// ✅ WORKS: Access the computed value through the reactive object
console.log(p.double)  // Returns the computed value
const result = p.double * 2  // Works perfectly
```

```rescript
let (count, setCount) = signal(0)

// ✅ CORRECT: Define computed directly in a reactive object
let p = tilia({
  double: computed(() => count.value * 2)
})

// ✅ WORKS: Access the computed value through the reactive object
Js.log(p.double)  // Returns the computed value
let result = p.double * 2  // Works perfectly
```

### Why Does This Restriction Exist?

This safety feature was introduced in **Tilia v4.0** to prevent a common class of runtime errors called "zombie computations" or "orphan computations."

#### Without This Protection (Pre-v4.0)

In earlier versions, orphan computations would:
1. Silently fail or return `undefined`
2. Cause obscure JavaScript errors deep in the stack
3. Make it very difficult to debug what went wrong

#### With This Protection (v4.0+)

Now you get:
1. **Immediate, clear error** at the point of misuse
2. **Descriptive message** explaining the problem
3. **Link to this documentation** with examples

The error message guides you to write correct code from the start, eliminating a whole class of hard-to-debug issues.

### The Three Reactive Contexts

Computations must be created inside one of these three contexts:

#### 1. `tilia({ ... })`

The primary way to create reactive objects:

```typescript
const app = tilia({
  count: signal(0),
  double: computed(() => app.count * 2),
  triple: computed(() => app.count * 3)
})
```

```rescript
let app = tilia({
  count: signal(0),
  double: computed(() => app.count * 2),
  triple: computed(() => app.count * 3)
})
```

#### 2. `carve({ derived } => { ... })`

For creating objects that reference themselves during construction:

```typescript
const app = carve(({ derived }) => ({
  count: signal(0),
  double: derived(self => self.count * 2),
  quadruple: derived(self => self.double * 2)  // References self.double
}))
```

```rescript
let app = carve(({ derived }) => {
  count: signal(0),
  double: derived(self => self.count * 2),
  quadruple: derived(self => self.double * 2)  // References self.double
})
```

#### 3. `derived(() => value)`

For creating standalone reactive values:

```typescript
const double = derived(() => count.value * 2)
console.log(double.value)  // Access via .value
```

```rescript
let double = derived(() => count.value * 2)
Js.log(double.value)  // Access via .value
```

### Common Scenarios

#### Scenario 1: Helper Functions

❌ **Wrong:**
```typescript
function makeFullName(firstName, lastName) {
  // Orphan created in the void!
  // Also: business logic polluted with reactive framework concepts (signals, computed)
  return computed(() => `${firstName.value} ${lastName.value}`)
}

const name = makeFullName(first, last)
console.log(name)  // ERROR: Cannot access value of an orphan computation
```

```rescript
let makeFullName = (firstName, lastName) => {
  // Orphan created in the void!
  // Also: business logic polluted with reactive framework concepts (signals, computed)
  computed(() => `${firstName.value} ${lastName.value}`)
}

let name = makeFullName(first, last)
Js.log(name)  // ERROR: Cannot access value of an orphan computation
```

❌ **Still Wrong (even if used in tilia):**
```typescript
function makeFullName(firstName, lastName) {
  // Creates orphan! Also mixes business logic with framework concerns
  return computed(() => `${firstName.value} ${lastName.value}`)
}

const user = tilia({
  fullName: makeFullName(first, last)  // Works, but wrong architecture
})
```

```rescript
let makeFullName = (firstName, lastName) => {
  // Creates orphan! Also mixes business logic with framework concerns
  computed(() => `${firstName.value} ${lastName.value}`)
}

let user = tilia({
  fullName: makeFullName(first, last)  // Works, but wrong architecture
})
```

✅ **Correct - Separate business logic from reactive wiring:**
```typescript
// Pure function: business logic (testable, reusable)
function formatFullName(firstName, lastName) {
  return `${firstName} ${lastName}`
}

// Reactive wiring: done inside tilia
const user = tilia({
  firstName: signal("Alice"),
  lastName: signal("Smith"),
  fullName: computed(() => formatFullName(user.firstName, user.lastName))
})

console.log(user.fullName)  // Works! "Alice Smith"
```

```rescript
// Pure function: business logic (testable, reusable)
let formatFullName = (firstName, lastName) => {
  `${firstName} ${lastName}`
}

// Reactive wiring: done inside tilia
let user = tilia({
  firstName: signal("Alice"),
  lastName: signal("Smith"),
  fullName: computed(() => formatFullName(user.firstName, user.lastName))
})

Js.log(user.fullName)  // Works! "Alice Smith"
```

**Why?** This pattern:
- ✅ Never creates orphan computations
- ✅ Keeps business logic pure and framework-agnostic (no signals, no computed, no library pollution)
- ✅ Separates business logic (testable `formatFullName()`) from reactive wiring
- ✅ Makes it clear where reactive boundaries are
- ✅ The `formatFullName()` function can be reused in non-reactive contexts (CLI tools, tests, other frameworks)

#### Scenario 2: Reusable Computations

❌ **Wrong:**
```typescript
const sharedComputed = computed(() => expensiveCalculation())  // Orphan!

const obj1 = tilia({ value: sharedComputed })
const obj2 = tilia({ value: sharedComputed })  // Won't share!
```

```rescript
let sharedComputed = computed(() => expensiveCalculation())  // Orphan!

let obj1 = tilia({ value: sharedComputed })
let obj2 = tilia({ value: sharedComputed })  // Won't share!
```

✅ **Correct:**
```typescript
// Create a standalone reactive value with derived()
const shared = derived(() => expensiveCalculation())

// Reference it from other objects
const obj1 = tilia({ 
  result: computed(() => shared.value * 2) 
})

const obj2 = tilia({
  result: computed(() => shared.value + 10)
})
```

```rescript
// Create a standalone reactive value with derived()
let shared = derived(() => expensiveCalculation())

// Reference it from other objects
let obj1 = tilia({ 
  result: computed(() => shared.value * 2) 
})

let obj2 = tilia({
  result: computed(() => shared.value + 10)
})
```

#### Scenario 3: Conditional Computations

❌ **Wrong:**
```typescript
const comp = condition 
  ? computed(() => a.value)
  : computed(() => b.value)  // Creates orphans!

const obj = tilia({ value: comp })  // Might work, might not
```

```rescript
let comp = if condition {
  computed(() => a.value)
} else {
  computed(() => b.value)  // Creates orphans!
}

let obj = tilia({ value: comp })  // Might work, might not
```

✅ **Correct (inside tilia):**
```typescript
const obj = tilia({
  value: computed(() => condition ? a.value : b.value)
})
```

```rescript
let obj = tilia({
  value: computed(() => if condition { a.value } else { b.value })
})
```

✅ **Correct (standalone with derived):**
```typescript
const value = derived(() => condition ? a.value : b.value)

// Use it anywhere
console.log(value.value)
```

```rescript
let value = derived(() => if condition { a.value } else { b.value })

// Use it anywhere
Js.log(value.value)
```

### The "Glue Zone" Should Not Exist

The **"Glue Zone"** is the space between creating a computation definition and inserting it into a reactive object. This zone should not exist at all.

#### ❌ Glue Zone Exists (Dangerous)
```typescript
// Computation definition created
const trouble = computed(() => ...)  // ← GLUE ZONE: computation floats in the void
// ... potentially many lines of code ...
// ... risk of using it as a value or passing it to wrong place ...

const app = tilia({ 
  value: trouble  // ← Finally inserted
})
```

```rescript
// Computation definition created
let trouble = computed(() => ...)  // ← GLUE ZONE: computation floats in the void
// ... potentially many lines of code ...
// ... risk of using it as a value or passing it to wrong place ...

let app = tilia({ 
  value: trouble  // ← Finally inserted
})
```

**Problem:** The computation exists as an orphan between creation and insertion. It can be accidentally used as a value or passed to the wrong place.

#### ✅ No Glue Zone (Correct)
```typescript
const app = tilia({ 
  value: computed(() => ...)  // ← Created inline, no glue zone
})
```

```rescript
let app = tilia({ 
  value: computed(() => ...)  // ← Created inline, no glue zone
})
```

**Solution:** The computation is created directly inside the reactive object. No opportunity for misuse.

**Preferred Pattern:** Keep related computations together in a single reactive object using `tilia()` or `carve()`. This makes your business logic easier to reason about compared to fragmenting it into many separate `signal()` or `derived()` values.

The safety proxy catches cases where a glue zone exists, ensuring computation definitions don't escape into places where they'd be treated as values.

### Technical Details

Under the hood, when you create a `computed()`, `source()`, or `store()` outside a reactive object:

1. It returns a **SafeProxy** wrapping the computation definition.
2. The proxy allows Tilia's internal properties to be accessed.
3. Any other property access throws the error.

This proxy is transparent when used correctly (inside `tilia`/`carve`/`derived`), but protects you from misuse.

### Related Documentation

- [Tilia v4.0 Release Notes](https://github.com/tiliajs/tilia/wiki/release-v4) - Full details on the safety improvements
- [Tilia README](https://github.com/tiliajs/guide) - Getting started guide
- [API Reference](/docs) - Complete API documentation

### Still Having Issues?

If you're still encountering this error and believe it's a false positive, please:

1. Check that you're using the latest version of Tilia
2. Review the patterns above to ensure your usage matches
3. Open an issue on [GitHub](https://github.com/tiliajs/tilia/issues) with a minimal reproduction

The Tilia community is here to help!

</section>

</main>

