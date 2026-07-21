## What happened

> Cannot modify or access the value of an orphan computation.

[`computed`](api.html#computed) returns a definition that tilia turns into a value when it is inserted into a [`tilia`](api.html#tilia) or [`carve`](api.html#carve) object. Reading, changing, serializing, or otherwise using that definition before insertion raises this error.

Only `computed` definitions use this orphan guard. [`source`](api.html#source) and [`store`](api.html#store) have different lifecycles.

## Define it where it is inserted

Do not keep a `computed` definition in an intermediate variable:

```typescript
const doubled = computed(() => count.value * 2);
console.log(doubled);
```

```rescript
let doubled = computed(() => count.value * 2)
Console.log(doubled)
```

Insert the definition directly into the reactive object:

```typescript
const counter = tilia({
  doubled: computed(() => count.value * 2),
});

console.log(counter.doubled);
```

```rescript
let counter = tilia({
  doubled: computed(() => count.value * 2),
})

Console.log(counter.doubled)
```

When the result must live on its own, use [`derived`](api.html#derived), which returns a signal whose current result is available at `.value`.

## Still seeing the error?

Check the stack frame above tilia's internals. It should point to the first operation that used the definition as a value. Move that `computed` call directly into the object that owns the property.

If a definition is already inserted directly and the error still occurs, [open a GitHub issue](https://github.com/tiliajs/tilia/issues) with a minimal reproduction and the complete stack trace.
