---
name: Channel.find
slug: find-channel-type
kind: type
module: core
since: "0.1"
sort: 275
summary: Combine local and authoritative answers for one engine find.
tags: []
signature.ts: "ReadChannel<T> & LocalChannel<T>"
signature.res: |-
  type Channel.find<'a> = {
    partial: array<'a> => unit,
    local: array<'a> => unit,
    fresh: array<'a> => unit,
    live: array<'a> => unit,
    fail: string => unit,
    end: unit => unit,
    finally: (unit => unit) => unit,
  }
label: Channel.find
---

`Channel.find` is the combined channel passed to a custom
[Source](api.html#source-type). TypeScript expresses it as the intersection
`ReadChannel<T> & LocalChannel<T>`; ReScript exports the named
`Channel.find<'a>` type.

It lets one engine find receive `partial` or `local` answers from storage and
`fresh` or `live` answers from an authoritative source. `fail`, `end`, and
`finally` use the [ReadChannel](api.html#read-channel-type) lifecycle. The
engine ignores an answer that would weaken the strongest claim already
published during that find.

```typescript
const empty = (channel: ReadChannel<Card> & LocalChannel<Card>) =>
  channel.partial([]);
```

```rescript
let empty = (channel: TiliaQuery.Channel.find<card>) =>
  channel.partial([])
```
