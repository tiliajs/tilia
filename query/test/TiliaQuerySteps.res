open VitestBdd
open MakeWorld

given("an {string} training app", ({step}, status: string) => {
  let (online_, setOnline) = Tilia.signal(status === "online")
  let (now_, setNow) = Tilia.signal(0.0)
  let stack = Stack.make()
  let papabase = Papabase.make(stack)
  let dexme = Dexme.make(stack)
  let app = make(~dexme, papabase, now_, online_)
  let view: ref<TiliaQuery.loadable<array<card>>> = ref(TiliaQuery.Loading)

  step("a set of language cards on a remote", (table: array<array<string>>) =>
    toRecords(table)->Array.forEach(card => papabase.upsert(card)->ignore)
  )

  step("time passes", () => {
    setNow(now_.value + 1.0)
    stack.flush()
  })

  step("a local cache of cards", (table: array<array<string>>) =>
    toRecords(table)->Array.forEach(card => dexme.cards.put(card)->ignore)
  )

  step("I go {string}", (status: string) => setOnline(status === "online"))

  step("I open the {string} deck", (deck: string) => {
    let query = {deck: deck->String.toLowerCase}
    Tilia.observe(() => view := app.array(query))
  })

  step("I should see loading", () => {
    expect(view.contents).toMatchObject(TiliaQuery.Loading)
  })

  step("I should see loaded with data", (table: array<array<string>>) => {
    let expected: array<card> = toRecords(table)
    expect(view.contents).toMatchObject(TiliaQuery.Loaded({data: expected}))
  })

  step("I upsert", (table: array<array<string>>) =>
    toRecords(table)->Array.forEach(card => app.upsert(card))
  )

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
