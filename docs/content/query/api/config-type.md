---
name: Config
slug: config-type
kind: type
module: core
since: "0.1"
sort: 205
summary: Configuration passed to make.
signature:
  ts: |-
    type Config<T, Q> = {
      id: (value: T) => string,
      matches: (query: Q, value: T) => boolean,
      remote: Remote<T, Q>,
      local?: Local<T, Q>,
      expiry?: Expiry,
      now?: () => number,
      key?: (query: Q) => string,
      sort?: (values: T[]) => T[]
    }
  res: |-
    type config<'a, 'query> = {
      id: 'a => string,
      matches: ('query, 'a) => bool,
      remote: remote<'a, 'query>,
      local?: local<'a, 'query>,
      expiry?: expiry,
      now?: unit => float,
      key?: 'query => string,
      sort?: array<'a> => array<'a>,
    }
tags: []
---

`Config` collects the required collection logic and adaptors, plus the optional cache, timing, identity and ordering settings passed to [make](api.html#make).
