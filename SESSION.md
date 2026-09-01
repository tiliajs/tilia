# Session — copy-on-write

Settled. Tests, then code.

## Why

`@lapa/tilia` folds a server delivery into a record the app is editing. To do
that it needs a three-way merge, and a three-way merge needs to know which
fields the app moved locally.

Today it recovers that from outside: it reads the row as it was from the
client's key-value store. That costs a read on every write, it needs a queue
for readers that arrive while the read is in flight, and over IndexedDB it can
still answer too late.

Tilia already knows. Every write goes through the proxy, and `Tilia.res:474`
already computes `hadKey` and `prev` before deciding anything. The information
is in hand and thrown away.

## What

A copy-on-write flavour of a tilia object. On the first write, a shallow copy
of the target is set aside. `diff` compares live to that copy.

```rescript
Tilia.cow.tilia: 'a => 'a          // like Tilia.tilia, copy on first write
Tilia.cow.diff: 'a => (array<string>, unit => 'a)
Tilia.cow.reset: 'a => unit
Tilia.cow.set: ('a, string, 'b) => unit
Tilia.cow.delete: ('a, string) => unit
```

`cow` is a record of closures, with `'a.` universals, the same pattern as
`type tilia`. It lives on the context: `make()` returns it, and `Tilia.cow` is
`_ctx.cow`. Isolated contexts have no other copy.

`diff` answers `(keys, original)`. The second is a thunk that clones the copy.
It is an ordinary object, a snapshot, not a view — call it before `reset`.

`diff` and `reset` on a non-cow object are normal: empty keys, no-op.
There is no error.

`reset` drops the copy. The object becomes its own original.

`cow.set` drops the copy and writes. Observers still run, a new copy is not
taken. A received record merged in place uses this. On a plain object, it is
a normal write. A rejected write is silent, like assign.

`cow.delete` is the same for removal.

No `cow.carve`. A row that needs a copy is wrapped with `cow.tilia` from
the start. Passing an existing tilia proxy returns it unchanged.

The proxy target cannot be swapped, so the copy is set aside and live keeps
mutating. Arrays are not a special case: `slice` then compare, and length
shrinks itself.

## Rules

**Traps are chosen in `proxify`.** Cow `set` / `delete` / `get` are a
separate handler set. `setCow` copies (or follows the copy on a computed
rebuild), then calls `set`. `deleteCow` copies, then calls `deleteProperty`.
`getCow` follows the copy on computed unwrap and wraps children as cow.
Cow is wrap time only: an existing proxy is not converted.

**The copy is a nullable field on the node.** Absent: not cow. `null`: cow, no
copy yet. An object: the original. Do not copy until the first Assign.

**On Assign.** If there is no copy yet, shallow-copy the target, then write.
Later Assigns leave the copy alone. A failed readonly write does not keep a
copy that was taken for that write.

**On Rebuild.** Computed rebuilds and `source` / `store` setters are not app
edits: write the live value onto the copy if it exists, so they are not named.
An `observe` that assigns `p.username = p.name` is Assign: that is a real
write. Only `Rebuild` leaves a computed in place.

**On Truth (`cow.set` / `cow.delete`).** Drop the copy, then write or delete.
Observers run. A new copy is not taken. A rejected write is silent. On a
plain object, this is a normal write or delete.

**Revert is `===`.** `diff` names a key when `has` or the value differs. Putting
a field back to the same reference drops the name.

**Membership is `has`, never `=== undefined`.** An optional field's original is
legitimately `undefined`. `Object.assign` keeps that.

**The original is a clone of the copy.** Nested objects are shared with the
live tree and drift with it. Writing a top-level field on the clone is
harmless; writing through a nested field reaches the live object.

**Children are cow too.** A child proxied from a cow node is a cow node. An
edit is usually `record.part.field`, which lands on the part.

**`diff` answers one object.** A child edited in place is not named on the
parent, because the parent's value for that key did not change (same
reference). `original.child` is the live child. `reset` is per object. After a
save, the caller walks. This is the line a caller will misread, so it belongs
in the doc comment in that sentence.

## Scenarios

Five `it` tests in `tilia/test/Tilia_test.res`, same shape as the rest of the
file: typed fixtures, no `%raw`, no table. Cow is an edge; do not grow this.

1. A field write is named and the original still has the old value. Putting
   it back drops the name. A snapshot already built does not move. A push on
   a nested array is named on the array, not the parent.
2. A nested object copies on its own, and `reset` is per object.
3. A computed rebuild is not named; assigning that key by hand is.
4. A truth write drops the original and does not take a new copy. Same for
   `cow.delete`.
5. On a plain proxy, `diff` / `reset` / `set` / `delete` are normal
   operations: no copy, no error. `cow.tilia` of an existing proxy does
   not add a copy.

## Also to update

`tilia/src/index.d.ts`, `tilia/src/Tilia.resi`, `tilia/llms.txt`, and the API
section of `README.md`. `AGENTS.md` asks for generated files to stay in sync,
and `llms.txt` is what an agent reads first.
