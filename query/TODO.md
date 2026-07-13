# TODO

- [ ] Orchestrate sync and pruning across multiple collections so they do not
      flood the app on boot or all run at the same time.
- [x] Implement inbound subscriptions.
  - [x] Apply values delivered through `receive.changed`.
  - [x] Apply ids delivered through `receive.removed`.
- [ ] Give `live` queries a way to shut down. An entry that reaches
      `LiveRemote` stays there forever: fetch skips it, tick never demotes
      it. If the live source (e.g. a subscription socket) drops while
      `online` stays true, the query is stuck fresh with no self-healing
      path — it needs a demotion back into normal refresh.
