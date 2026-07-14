open VitestBdd
open MakeWorld

type queryRecord = {ids: array<string>}

@scope("JSON") @val external parseRecord: string => queryRecord = "parse"

// Step definitions for TiliaQuery.feature. The `given` builds the world —
// simulated remote (Papabase behind a Network), local store (Dexme) and the
// app — then each step drives or observes it the way a real app would.
//
// Timing: vitest-bdd awaits every step, and the clock/tick steps end on a
// macrotask (`settled`), so every pending local (Dexme) answer lands
// between two steps. Remote responses are held by the Network and only
// arrive when a `time passes` step flushes it.
given("an {string} training app", ({step}, status: string) => {
  let (online_, setOnline) = Tilia.signal(status === "online")
  let (now_, setNow) = Tilia.signal(0.0)
  let network = Network.make()
  let papabase = Papabase.make(network)
  let dexme = Dexme.make()
  let live = Live.make(network)
  // A ref so "I restart the app" can rebuild the engine on the same stores.
  let cards = ref(make(~dexme, ~live, papabase, () => now_.value, online_))
  let view: ref<TiliaQuery.loadable<array<card>>> = ref(TiliaQuery.Loading)
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
    cards := make(~dexme, ~live, papabase, () => now_.value, online_)
    // Boot reloads the outbox from the kv, answering on the microtask queue.
    settled()
  })

  step("deck {string} is in local db", (deck: string) => {
    let app = make(~dexme, papabase, () => now_.value, online_)
    let query = {deck: deck->String.toLowerCase}
    let close = Tilia.observe(() => app.array(query)->ignore)
    network.flush()
    settled()->Promise.thenResolve(
      () => {
        close()
        app.dispose()
      },
    )
  })

  step("I go {string}", (status: string) => setOnline(status === "online"))

  step("the remote is failing with {string}", (message: string) =>
    papabase._failing(Some(message))
  )

  step("the remote recovers", () => papabase._failing(None))

  // Observe like a UI binding would: the callback re-runs whenever the
  // query result changes, keeping `view` in sync.
  step("I open the {string} deck", (deck: string) => {
    let query = {deck: deck->String.toLowerCase}
    closeDeck :=
      Tilia.observe(
        () => {
          view := cards.contents.array(query)
          switch view.contents {
          | TiliaQuery.Loaded({data}) => Console.log(data)
          | _ => Console.log("not loaded")
          }
        },
      )
  })

  // Stop observing, like a UI unmount: the query is no longer "seen".
  step("I close the deck", () => closeDeck.contents())

  step("I should see loading", () => {
    expect(view.contents).toMatchObject(TiliaQuery.Loading)
  })

  step("I should see not local", () => {
    expect(view.contents).toMatchObject(TiliaQuery.NotLocal)
  })

  step("I should see failed with {string}", (message: string) => {
    expect(view.contents).toMatchObject(TiliaQuery.Failed({message: message}))
  })

  step("I should see {string} loaded with data", (source: string, table: array<array<string>>) => {
    let expected: array<card> = toRecords(table)
    expect(view.contents).toMatchObject(
      TiliaQuery.Loaded({data: expected, fresh: source === "remote"}),
    )
  })

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

  let findRejection = (id: string) =>
    cards.contents.status.rejected
    ->Array.find(rejection => rejection.id === id)
    ->Option.getOrThrow(~message=`no rejection for "${id}"`)

  step("I retry the rejection for {string}", (id: string) =>
    cards.contents.retry(findRejection(id))
  )

  step("I discard the rejection for {string}", (id: string) =>
    cards.contents.discard(findRejection(id))
  )

  step("remote should not have {string}", (id: string) => {
    expect(papabase._select(c => c.id === id)->Array.length).toBe(0)
  })

  // `_select` looks straight inside the simulated stores — test-only
  // inspection, this is not something an adaptor can or should do.
  step("remote should have", (table: array<array<string>>) =>
    toRecords(table)->Array.forEach(
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

  let expectMemory = (deck, table) => {
    let query = {deck: deck->String.toLowerCase}
    let ids = toRecords(table)->Array.map(row => row.id)
    expect(cards.contents._ids(query)).toEqual(Some(ids))
  }

  let expectLocal = (deck, table) => {
    let query = {deck: deck->String.toLowerCase}
    let ids = toRecords(table)->Array.map(row => row.id)
    let key = DexmeAdaptor.kvKey(~tag="query", ~key=TiliaQuery.sortedStringify(query))
    let entry =
      dexme.kv._select(entry => entry.key === key)
      ->Array.get(0)
      ->Option.getOrThrow(~message=`local has no query for "${deck}"`)
    expect(parseRecord(entry.value).ids).toEqual(ids)
  }

  step("memory query {string} should have ids", expectMemory)

  step("local query {string} should have ids", expectLocal)

  step("memory and local query {string} should have ids", (deck, table) => {
    expectMemory(deck, table)
    expectLocal(deck, table)
  })

  step("memory query {string} should be dropped", (deck: string) => {
    let query = {deck: deck->String.toLowerCase}
    expect(cards.contents._ids(query)).toEqual(None)
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
    supersededChannel().set(values)
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
