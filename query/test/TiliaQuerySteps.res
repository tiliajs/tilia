open VitestBdd
open MakeWorld

// Step definitions for TiliaQuery.feature. The `given` builds the world —
// simulated remote (Papabase behind a Network), local store (Dexme) and the
// app — then each step drives or observes it the way a real app would.
//
// Timing: vitest-bdd awaits every step, so plain promise results (Dexme)
// land between two steps on their own. Remote responses are held by the
// Network and only arrive when a `time passes` step flushes it.
given("an {string} training app", ({step}, status: string) => {
  let (online_, setOnline) = Tilia.signal(status === "online")
  let (now_, setNow) = Tilia.signal(0.0)
  let network = Network.make()
  let papabase = Papabase.make(network)
  let dexme = Dexme.make()
  let app = make(~dexme, papabase, now_, online_)
  let view: ref<TiliaQuery.loadable<array<card>>> = ref(TiliaQuery.Loading)

  step("a set of language cards on a remote", (table: array<array<string>>) =>
    toRecords(table)->Array.forEach(card => papabase.upsert(card)->ignore)
  )

  // Advance the clock and deliver every pending network response.
  step("time passes", () => {
    setNow(now_.value + 1.0)
    network.flush()
  })

  step("a local cache of cards", (table: array<array<string>>) =>
    toRecords(table)->Array.forEach(card => dexme.cards.put(card)->ignore)
  )

  step("I go {string}", (status: string) => setOnline(status === "online"))

  // Observe like a UI binding would: the callback re-runs whenever the
  // query result changes, keeping `view` in sync.
  step("I open the {string} deck", (deck: string) => {
    let query = {deck: deck->String.toLowerCase}
    Tilia.observe(() => view := app.array(query))
  })

  step("I should see loading", () => {
    expect(view.contents).toMatchObject(TiliaQuery.Loading)
  })

  step("I should see not local", () => {
    expect(view.contents).toMatchObject(TiliaQuery.NotLocal)
  })

  step("I should see {string} loaded with data", (local: string, table: array<array<string>>) => {
    let expected: array<card> = toRecords(table)
    expect(view.contents).toMatchObject(
      TiliaQuery.Loaded({data: expected, local: local === "local"}),
    )
  })

  step("I upsert", (table: array<array<string>>) =>
    toRecords(table)->Array.forEach(card => app.upsert(card))
  )

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
})
