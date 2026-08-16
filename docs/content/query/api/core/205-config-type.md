---
name: Config
slug: config-type
kind: type
module: core
since: "0.1"
sort: 205
summary: Configuration passed to make.
tags: []
signature.ts: |-
  type Config<T, Q> = {
    id: (value: T) => string,
    matches: (query: Q, value: T) => boolean,
    remote: Remote<T, Q>,
    local?: Local<T, Q>,
    expiry?: Expiry,
    now?: () => number,
    key?: (query: Q) => string,
    sort?: (query: Q) => (values: T[]) => T[],
    merge?: (change: Change<T>, remote: T) => boolean
  }
signature.res: |-
  type config<'query, 'a> = {
    id: 'a => string,
    matches: ('query, 'a) => bool,
    remote: remote<'query, 'a>,
    local?: local<'query, 'a>,
    expiry?: expiry,
    now?: unit => float,
    key?: 'query => string,
    sort?: 'query => array<'a> => array<'a>,
    merge?: (~change: change<'a>, ~remote: 'a) => bool,
  }
label: Config
---

`Config` collects the required collection logic and adaptors, plus the optional cache, timing, identity, ordering, and merge settings passed to [make](api.html#make).

- `sort` returns the result sorter for a query.
- `merge` receives the local [Change](api.html#change-type) and the remote value. Merge the remote value into the local value in place and return `true`, or return `false` to keep remote truth and record a conflict.
