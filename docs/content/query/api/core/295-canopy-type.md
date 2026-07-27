---
name: Canopy
slug: canopy-type
kind: type
module: core
since: "0.1"
sort: 295
summary: Debug view of observed and cached query keys.
tags: []
signature.ts: |-
  type Canopy = {
    live: string[],
    idle: string[]
  }
signature.res: |-
  type canopy = {
    live: array<string>,
    idle: array<string>,
  }
label: Canopy
---

`Canopy` is returned by [_canopy](api.html#canopy).

- `live` contains query keys observed by the tilia graph.
- `idle` contains unobserved query keys still held in memory.

It is intended for debugging and tooling.
