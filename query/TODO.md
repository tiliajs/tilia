# TODO

- [ ] Orchestrate sync and pruning across multiple collections so they do not
      flood the app on boot or all run at the same time.
- [ ] Join an upserted row to matching query records that exist only in local
      storage, so a persisted query picks it up without a remote refresh.
