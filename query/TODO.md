# TODO

- [ ] Orchestrate sync and pruning across multiple collections so they do not
      flood the app on boot or all run at the same time.
- [ ] Apply upserts optimistically to every matching query in memory and local
      storage. Moving a row must remove it from queries it no longer matches,
      and a new row must join matching persisted queries.
- [ ] Mark ids from pending outbox operations during local purge so optimistic
      rows cannot be swept before remote confirmation.
