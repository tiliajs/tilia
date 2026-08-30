open VitestBdd
open MakeWorld

type queryRecord = {ids: array<string>}
type rejectionRecord = {
  kind: string,
  id: string,
  base: string,
  edited: string,
  message: string,
}
type mergeRecord = {
  context: string,
  id: string,
  base: string,
  edited: string,
  remote: string,
}

@scope("JSON") @val external parseRecord: string => queryRecord = "parse"

// Table cells arrive as strings. `version` is a number on the server, so a
// row crossing into or out of it has to be converted.
@val external asFloat: 'a => float = "Number"

// Step definitions for TiliaQuery.feature. The `given` builds the world —
// simulated remote (Papabase behind a Network), local store (Dexme) and the
// app — then each step drives or observes it the way a real app would.
//
// Timing: vitest-bdd awaits every step, and the clock/tick steps end on a
// macrotask (`settled`), so every pending local (Dexme) answer lands
// between two steps. Remote responses are held by the Network and only
// arrive when a `time passes` step flushes it.
let numericVersion = (card: card) =>
  switch card.version {
  | Some(version) => {...card, version: asFloat(version)}
  | None => card
  }

given("an {string} training app", ({step}, status: string) => {
  let (online_, setOnline) = Tilia.signal(status === "online")
  let (now_, setNow) = Tilia.signal(0.0)
  let network = Network.make()
  let papabase = Papabase.make(network)
  let dexme = Dexme.make()
  let live = Live.make(network)
  let push = Push.make()
  let rules = Rules.make()
  let merge = Merge.make()
  // Failures the read site is never told about, because it still had
  // something to show.
  let errors: ref<array<(query, string)>> = ref([])
  let onError = (~query, ~message) => errors := errors.contents->Array.concat([(query, message)])
  // A ref so "I restart the app" can rebuild the engine on the same stores.
  let cards = ref(
    make(~dexme, ~live, ~push, ~rules, ~merge, ~onError, papabase, () => now_.value, online_),
  )
  let view: ref<TiliaQuery.loadable<array<card>>> = ref(TiliaQuery.Loading)
  let single: ref<TiliaQuery.loadable<card>> = ref(TiliaQuery.Loading)
  let closeDeck: ref<unit => unit> = ref(() => ())

  step("a set of language cards on a remote", (table: array<array<string>>) =>
    toRecords(table)->Array.forEach(card => papabase.upsert(card)->ignore)
  )

  // Write straight to the server, behind the app's back: the app only sees
  // this after a refresh.
  step("the remote is updated with", (table: array<array<string>>) =>
    toRecords(table)->Array.forEach(card => papabase.upsert(card)->ignore)
  )

  step("the subscription changes", (table: array<array<string>>) =>
    cards.contents.receive.changed(toRecords(table))
  )

  step("the subscription removes {string}", (id: string) => cards.contents.receive.removed([id]))

  // Delete straight on the server: the local copy lingers until the purge
  // sweeps it.
  step("the remote removes {string}", (id: string) => papabase.remove(id)->ignore)

  // Dexme answers on the microtask queue, sometimes through several chained
  // promises (the purge: kv read, then row enumeration, then removes).
  // Waiting one macrotask drains the whole queue, so every pending local
  // answer has landed before the next step runs.
  let settled = () => Promise.make((resolve, _) => setTimeout(() => resolve(), 0)->ignore)
  let query = (~seen=None, deck: string): query => {
    deck: deck->String.toLowerCase,
    seen,
  }

  // Advance the clock and deliver every pending network response.
  let advanceClock = (ms: float) => {
    setNow(now_.value + ms)
    network.flush()
    settled()
  }

  step("time passes", () => advanceClock(1.0))
  step("{number} minutes pass", (minutes: float) => advanceClock(minutes * 60.0 * 1000.0))
  step("{number} seconds pass", (seconds: float) => advanceClock(seconds * 1000.0))
  step("{number} days pass", (days: float) => advanceClock(days * 86_400_000.0))
  step("tick is called", () => {
    cards.contents.tick()
    settled()
  })

  // A restart: the engine instance is torn down and rebuilt on the same
  // local and remote stores, like the app coming back after a reload.
  step("I restart the app", () => {
    cards.contents.dispose()
    cards :=
      make(~dexme, ~live, ~push, ~rules, ~merge, ~onError, papabase, () => now_.value, online_)
    // Boot reloads the outbox from the kv, answering on the microtask queue.
    settled()
  })

  // Rule 17: the app comes back on a store whose replay is synchronous, so
  // the rows are in the engine before anything can ask for them.
  step("the store replays its outbox during construction", (table: array<array<string>>) => {
    cards.contents.dispose()
    cards := makeSync(toRecords(table), () => now_.value, online_)
  })

  step("deck {string} is in local db", (deck: string) => {
    let app = make(~dexme, papabase, () => now_.value, online_)
    let close = Tilia.observe(() => app.array(query(deck))->ignore)
    network.flush()
    settled()->Promise.thenResolve(
      () => {
        close()
        app.dispose()
      },
    )
  })

  step("I go {string}", (status: string) => setOnline(status === "online"))

  step("the remote is failing with {string}", (message: string) => papabase._failing(Some(message)))

  step("the remote recovers", () => papabase._failing(None))

  step("the remote push is unavailable", () => push.unavailable = true)

  step("the remote push recovers", () => {
    push.unavailable = false
    rules.transientFrom = None
  })

  // The server holds this row and answers `conflict` for that id: the write
  // is not refused, it is out of date.
  step("the remote conflicts {string} with", (id: string, table: array<array<string>>) => {
    let row = numericVersion(toRecords(table)->Array.getUnsafe(0))
    papabase._put(row)
    rules.conflicts->Dict.set(id, row)
  })

  step("the remote rejects {string} with {string}", (id: string, message: string) =>
    rules.rejects->Dict.set(id, message)
  )

  step("the remote stops rejecting {string}", (id: string) => rules.rejects->Dict.delete(id))

  step("the remote replies out of order", () => rules.reversed = true)

  step("the remote is transient from {string}", (id: string) => rules.transientFrom = Some(id))

  step("the remote fails the batch with {string} after {string}", (
    message: string,
    after: string,
  ) => rules.failAfter = Some((after, message)))

  step("the remote push should have been attempted {number} time(s)", (count: float) =>
    expect(push.attempts).toBe(count->Float.toInt)
  )

  // Observe like a UI binding would: the callback re-runs whenever the
  // query result changes, keeping `view` in sync.
  let openDeck = query => {
    closeDeck :=
      Tilia.observe(() => {
        view := cards.contents.array(query)
        switch view.contents {
        | TiliaQuery.Loaded({data}) => Console.log(data)
        | _ => Console.log("not loaded")
        }
      })
  }

  // The same binding over `one`, which selects the first row of a query.
  let openOne = query => {
    closeDeck := Tilia.observe(() => single := cards.contents.one(query))
  }

  step("I open the {string} deck", (deck: string) => openDeck(query(deck)))

  step("I open one card from the {string} deck", (deck: string) => openOne(query(deck)))

  step("I open one card from the {string} deck filtered by seen {string}", (
    deck: string,
    seen: string,
  ) => openOne(query(~seen=Some(seen), deck)))

  step("I open the {string} deck filtered by seen {string}", (deck: string, seen: string) =>
    openDeck(query(~seen=Some(seen), deck))
  )

  // Stop observing, like a UI unmount: the query is no longer "seen".
  step("I close the deck", () => closeDeck.contents())

  step("I should see loading", () => {
    expect(view.contents).toMatchObject(TiliaQuery.Loading)
  })

  let claimOf = (name: string) =>
    switch name {
    | "partial" => TiliaQuery.Partial
    | "local" => TiliaQuery.Local
    | "fresh" => TiliaQuery.Fresh
    | other => throw(Invalid_argument(`unknown claim "${other}"`))
    }

  step("I should see no data because offline", () => {
    expect(view.contents).toMatchObject(TiliaQuery.NoData({reason: TiliaQuery.Offline}))
  })

  step("I should see no data because failed with {string}", (message: string) => {
    expect(view.contents).toMatchObject(
      TiliaQuery.NoData({reason: TiliaQuery.Failed({message: message})}),
    )
  })

  step("I should see {string} loaded with data", (claim: string, table: array<array<string>>) => {
    let expected: array<card> = toRecords(table)
    expect(view.contents).toMatchObject(TiliaQuery.Loaded({claim: claimOf(claim), data: expected}))
  })

  step("I should see {string} loaded with no rows", (claim: string) => {
    expect(view.contents).toMatchObject(TiliaQuery.Loaded({claim: claimOf(claim), data: []}))
  })

  step("I should see the {string} card", (claim: string, table: array<array<string>>) => {
    let expected = toRecords(table)->Array.getUnsafe(0)
    expect(single.contents).toMatchObject(
      TiliaQuery.Loaded({claim: claimOf(claim), data: expected}),
    )
  })

  step("I should see no data because no {string} match", (claim: string) => {
    expect(single.contents).toMatchObject(
      TiliaQuery.NoData({reason: TiliaQuery.NoMatch({claim: claimOf(claim)})}),
    )
  })

  // A store with no query index can hold rows without claiming they are the
  // whole answer.
  step("the local store answers partially", () => dexme.partial = true)

  step("the local store holds nothing", () =>
    expect(dexme.cards._select(_ => true)->Array.length).toBe(0)
  )

  step("onError should have received {string} for {string}", (message: string, deck: string) => {
    let expected = query(deck)
    expect(errors.contents->Array.some(((q, m)) => m === message && q == expected)).toBe(true)
  })

  step("onError should have received nothing", () => expect(errors.contents->Array.length).toBe(0))

  step("I upsert", (table: array<array<string>>) =>
    toRecords(table)->Array.forEach(card => cards.contents.upsert(card))
  )

  step("I remove {string}", (id: string) => cards.contents.remove(id))

  step("status should have {number} pending", (count: float) =>
    expect(cards.contents.status.pending).toBe(count->Float.toInt)
  )

  step("status should have {number} rejected", (count: float) =>
    expect(cards.contents.status.rejected->Array.length).toBe(count->Float.toInt)
  )

  let rejectionId = (rejection: TiliaQuery.rejection<card>) =>
    switch rejection {
    | TiliaQuery.CreateConflict({edited})
    | TiliaQuery.CreateFailed({edited}) =>
      edited.id
    | TiliaQuery.UpdateConflict({edited})
    | TiliaQuery.UpdateFailed({edited}) =>
      edited.id
    | TiliaQuery.RemoveConflict({base})
    | TiliaQuery.RemoveFailed({base}) =>
      base.id
    }

  let findRejection = (id: string) =>
    cards.contents.status.rejected
    ->Array.find(rejection => rejectionId(rejection) === id)
    ->Option.getOrThrow(~message=`no rejection for "${id}"`)

  step("status should have rejection", (table: array<array<string>>) => {
    let actual: array<rejectionRecord> = cards.contents.status.rejected->Array.map(
      rejection =>
        switch rejection {
        | TiliaQuery.CreateConflict({edited}) => {
            kind: "create conflict",
            id: edited.id,
            base: "",
            edited: edited.seen,
            message: "",
          }
        | TiliaQuery.CreateFailed({edited, message}) => {
            kind: "create failed",
            id: edited.id,
            base: "",
            edited: edited.seen,
            message,
          }
        | TiliaQuery.UpdateConflict({base, edited}) => {
            kind: "update conflict",
            id: edited.id,
            base: base.seen,
            edited: edited.seen,
            message: "",
          }
        | TiliaQuery.UpdateFailed({base, edited, message}) => {
            kind: "update failed",
            id: edited.id,
            base: base.seen,
            edited: edited.seen,
            message,
          }
        | TiliaQuery.RemoveConflict({base}) => {
            kind: "remove conflict",
            id: base.id,
            base: base.seen,
            edited: "",
            message: "",
          }
        | TiliaQuery.RemoveFailed({base, message}) => {
            kind: "remove failed",
            id: base.id,
            base: base.seen,
            edited: "",
            message,
          }
        },
    )
    let expected: array<rejectionRecord> = toRecords(table)
    expect(actual).toEqual(expected)
  })

  // Kept after the retry, the way an application holding the record does.
  let retried: ref<option<TiliaQuery.rejection<card>>> = ref(None)

  step("I retry the rejection for {string}", (id: string) => {
    let rejection = findRejection(id)
    retried := Some(rejection)
    cards.contents.retry(rejection)
  })

  step("the retried rejection should still show english {string}", (english: string) => {
    let rejection = retried.contents->Option.getOrThrow(~message="no rejection was retried")
    let card = switch rejection {
    | TiliaQuery.CreateConflict({edited})
    | TiliaQuery.CreateFailed({edited})
    | TiliaQuery.UpdateConflict({edited})
    | TiliaQuery.UpdateFailed({edited}) => edited
    | TiliaQuery.RemoveConflict({base})
    | TiliaQuery.RemoveFailed({base}) => base
    }
    expect(card.english).toBe(english)
  })

  step("I discard the rejection for {string}", (id: string) =>
    cards.contents.discard(findRejection(id))
  )

  step("merge calls are cleared", () =>
    merge.calls->Array.splice(~start=0, ~remove=merge.calls->Array.length, ~insert=[])->ignore
  )

  step("the merge rejects remote values", () => merge.accepted = false)

  step("merge should have received", (table: array<array<string>>) => {
    let actual: array<mergeRecord> = merge.calls->Array.map(
      call =>
        switch call.change {
        | TiliaQuery.Clean({value: card}) => {
            context: "clean",
            id: card.id,
            base: card.seen,
            edited: "",
            remote: call.remote.seen,
          }
        | TiliaQuery.Created({edited}) => {
            context: "created",
            id: edited.id,
            base: "",
            edited: edited.seen,
            remote: call.remote.seen,
          }
        | TiliaQuery.Updated({base, edited}) => {
            context: "updated",
            id: edited.id,
            base: base.seen,
            edited: edited.seen,
            remote: call.remote.seen,
          }
        | TiliaQuery.Removed({base}) => {
            context: "removed",
            id: base.id,
            base: base.seen,
            edited: "",
            remote: call.remote.seen,
          }
        },
    )
    let expected: array<mergeRecord> = toRecords(table)
    expect(actual).toEqual(expected)
  })

  step("remote should not have {string}", (id: string) => {
    expect(papabase._select(c => c.id === id)->Array.length).toBe(0)
  })

  // `_select` looks straight inside the simulated stores — test-only
  // inspection, this is not something an adaptor can or should do.
  step("remote should have", (table: array<array<string>>) =>
    toRecords(table)
    ->Array.map(numericVersion)
    ->Array.forEach(
      (card: card) => {
        let found =
          papabase._select(c => c.id === card.id)
          ->Array.get(0)
          ->Option.getOrThrow(~message=`remote has no card "${card.id}"`)
        expect(found).toMatchObject(card)
      },
    )
  )

  step("local should not have {string}", (id: string) => {
    expect(dexme.cards._select(c => c.id === id)->Array.length).toBe(0)
  })

  step("local should have", (table: array<array<string>>) =>
    toRecords(table)->Array.forEach(
      (card: card) => {
        let found =
          dexme.cards._select(c => c.id === card.id)
          ->Array.get(0)
          ->Option.getOrThrow(~message=`local has no card "${card.id}"`)
        expect(found).toMatchObject(card)
      },
    )
  )

  let expectLocal = (deck, table) => {
    let ids = toRecords(table)->Array.map(row => row.id)
    let key = DexmeAdaptor.kvKey(~tag="query", ~key=TiliaQuery.sortedStringify(query(deck)))
    let entry =
      dexme.kv._select(entry => entry.key === key)
      ->Array.get(0)
      ->Option.getOrThrow(~message=`local has no query for "${deck}"`)
    expect(parseRecord(entry.value).ids).toEqual(ids)
  }

  step("local query {string} should have ids", expectLocal)

  step("status rejections should be in order", (table: array<array<string>>) => {
    let expected =
      table
      ->Array.slice(~start=1, ~end=table->Array.length)
      ->Array.map(row => row->Array.getUnsafe(0))
    expect(cards.contents.status.rejected->Array.map(rejectionId)).toEqual(expected)
  })

  step("query {string} should be dropped from memory", (deck: string) => {
    let key = TiliaQuery.sortedStringify(query(deck))
    let canopy = cards.contents._canopy()
    expect(canopy.live->Array.includes(key) || canopy.idle->Array.includes(key)).toBe(false)
  })

  // ================ Live source controls
  // The scenario plays the subscription source, driving the channel handles
  // the `Live` instrumentation keeps.

  let liveChannel = () => live.channel->Option.getOrThrow(~message="no fetch happened yet")
  let supersededChannel = () =>
    live.superseded->Option.getOrThrow(~message="no fetch was superseded yet")

  step("the remote supports live queries", () => live.enabled = true)

  step("the live source ends during fetch", () => live.endsInFetch = true)

  step("the live source delivers", (table: array<array<string>>) => {
    let values: array<card> = toRecords(table)
    liveChannel().live(values)
  })

  step("the live source fails with {string}", (message: string) => liveChannel().fail(message))

  step("the live source ends", () => liveChannel().end())

  step("the superseded fetch delivers", (table: array<array<string>>) => {
    let values: array<card> = toRecords(table)
    supersededChannel().fresh(values)
  })

  step("the superseded fetch fails with {string}", (message: string) =>
    supersededChannel().fail(message)
  )

  step("the source teardown should have run {number} time(s)", (count: float) =>
    expect(live.cleanups).toBe(count->Float.toInt)
  )

  step("the remote fetch should have run {number} time(s)", (count: float) =>
    expect(live.fetches).toBe(count->Float.toInt)
  )

  step("I dispose the app", () => cards.contents.dispose())
})
