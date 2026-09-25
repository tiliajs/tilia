open EpureVitest

type entry = {key: string, value: string}
type keyRow = {key: string}

// Step definitions for IndexedDb.feature. The keyspace answers through a
// callback, so a read step returns the promise of its answer and @epure/vitest
// waits for it: no counting of ticks, and a read that never answers fails by
// timing out rather than by passing.
given("a keyspace", ({step}) => {
  let control = ref(None)
  let errors: ref<array<JsError.t>> = ref([])

  let build = (~failOpen=false, ~present=true, ()) => {
    if present {
      control := Some(FakeIndexedDb.make(~failOpen, ()))
    } else {
      control := None
      FakeIndexedDb.uninstall()
    }
    TiliaQueryIndexedDb.make({
      name: "cards",
      onError: error => errors := errors.contents->Array.concat([error]),
    })
  }

  let kv = ref(build())
  let fake = () => control.contents->Option.getOrThrow(~message="no fake database")
  let settled = () => Promise.make((resolve, _) => setTimeout(() => resolve(), 0)->ignore)

  let read = (~tag, ~keys=?) =>
    Promise.make((resolve, _) => kv.contents.get(~tag, ~keys?, ~set=values => resolve(values)))
  let list = tag => Promise.make((resolve, _) => kv.contents.keys(~tag, ~set=keys => resolve(keys)))

  step("the database cannot open", () => kv := build(~failOpen=true, ()))

  step("there is no IndexedDB at all", () => kv := build(~present=false, ()))

  step("the database has opened", () => settled())

  step("time passes", () => settled())

  step("I write under {string}", (tag: string, table: array<array<string>>) =>
    toRecords(table)->Array.forEach(
      (entry: entry) => kv.contents.set(~tag, ~key=entry.key, Some(entry.value)),
    )
  )

  step("I write {number} rows under {string}", (count: float, tag: string) =>
    Array.make(~length=count->Float.toInt, 0)->Array.forEachWithIndex(
      (_, index) =>
        kv.contents.set(~tag, ~key=`id-${index->Int.toString}`, Some(index->Int.toString)),
    )
  )

  step("I delete {string} under {string}", (key: string, tag: string) =>
    kv.contents.set(~tag, ~key, None)
  )

  step("transactions are counted from now", () => fake().transactions = 0)

  step("every transaction aborts", () => fake().failing = true)

  step("transactions succeed again", () => fake().failing = false)

  step("{number} transaction(s) should have been used", (count: float) =>
    expect(fake().transactions).toBe(count->Float.toInt)
  )

  let expectValues = (values, table: array<array<string>>) =>
    expect(values).toEqual(toRecords(table)->Array.map((entry: entry) => entry.value))

  step("reading {string} should answer", (tag: string, table) =>
    read(~tag)->Promise.thenResolve(values => expectValues(values, table))
  )

  step("reading {string} for {string} should answer", (tag: string, keys: string, table) =>
    read(~tag, ~keys=keys->String.split(", "))->Promise.thenResolve(
      values => expectValues(values, table),
    )
  )

  // Written and read in one step, with no boundary between them for the
  // scheduled flush to slip through: this is the read doing the flushing.
  step("writing {string} under {string} and reading it back at once should answer {string}", (
    key: string,
    tag: string,
    expected: string,
  ) => {
    kv.contents.set(~tag, ~key, Some(expected))
    read(~tag, ~keys=[key])->Promise.thenResolve(values => expect(values).toEqual([expected]))
  })

  step("reading {string} should answer nothing", (tag: string) =>
    read(~tag)->Promise.thenResolve(values => expect(values).toEqual([]))
  )

  step("listing {string} should answer", (tag: string, table: array<array<string>>) =>
    list(tag)->Promise.thenResolve(
      keys => expect(keys).toEqual(toRecords(table)->Array.map((entry: keyRow) => entry.key)),
    )
  )

  step("listing {string} should answer nothing", (tag: string) =>
    list(tag)->Promise.thenResolve(keys => expect(keys).toEqual([]))
  )

  step("listing {string} should have {number} keys", (tag: string, count: float) =>
    list(tag)->Promise.thenResolve(keys => expect(keys->Array.length).toBe(count->Float.toInt))
  )

  // The read goes out while the database is still opening; the answer is
  // kept for the step that asks about it.
  let early: ref<option<promise<array<string>>>> = ref(None)

  step("I read {string} without waiting for the database", (tag: string) =>
    early := Some(read(~tag))
  )

  step("the read should have answered", (table: array<array<string>>) =>
    early.contents
    ->Option.getOrThrow(~message="no early read")
    ->Promise.thenResolve(values => expectValues(values, table))
  )

  step("an error should have been reported", () =>
    expect(errors.contents->Array.length > 0).toBe(true)
  )
})
