open VitestBdd
open Tilia

type loadable<'a> = TiliaQuery.loadable<'a> = Loading | Loaded('a) | NotFound

let sleep: unit => promise<unit> = async () =>
  %raw(`new Promise(resolve => setTimeout(resolve, 10))`)

type item = {id: string, name: string, count: int}
type itemQuery = {status: string}
type tagQuery = {tag: string}
type sortedQuery = {status: string, owner: string}
type reversedQuery = {owner: string, status: string}

let item = (id, name, count) => {id, name, count}

module Assert = {
  let item = (actual, expected) => expect(actual).toEqual(expected)

  let array = result =>
    switch result {
    | Loaded(array) => array
    | _ => failwith("Expected array data")
    }

  let dict = result =>
    switch result {
    | Loaded(dict) => dict
    | _ => failwith("Expected dict data")
    }

  let first = (array, expected) =>
    switch array[0] {
    | Some(value) => item(value, expected)
    | None => failwith("Expected first array item")
    }

  let entry = (dict, id, expected) =>
    switch TiliaQuery.Object.get(dict, id) {
    | Value(value) => item(value, expected)
    | _ => failwith("Expected dict item")
    }
}

// Fake Supabase adaptor to show how to adapt @tilia/query to any remote source.
module Papabase = {
  type api<'a, 'query> = {
    fetch: 'query => promise<array<'a>>,
    upsert: (string, 'a) => promise<unit>,
  }

  let make = (_table, id, api, ~stale=?, ~gc=?, ~now=?, ~invalidates=?) =>
    TiliaQuery.make(
      ~id,
      ~fetch=api.fetch,
      ~upsert=api.upsert,
      ~stale?,
      ~gc?,
      ~now?,
      ~invalidates?,
      (),
    )
}

describe("TiliaQuery", () => {
  it("should cache query data", async () => {
    let count = ref(0)
    let api: Papabase.api<item, itemQuery> = {
      fetch: async query => {
        expect(query.status).toBe("active")
        count := count.contents + 1
        await sleep()
        [item("todo-1", "Buy milk", count.contents)]
      },
      upsert: async (_, _) => (),
    }

    let items = Papabase.make("items", item => item.id, api)
    let active = items.array({status: "active"})
    let todo1 = derived(() => items.get("todo-1"))

    expect(active).toEqual(Loading)
    expect(todo1.value).toEqual(NotFound)

    await sleep()

    expect(items.array({status: "active"})).toEqual(Loaded([item("todo-1", "Buy milk", 1)]))
    expect(todo1.value).toEqual(Loaded(item("todo-1", "Buy milk", 1)))
    items.dict({status: "active"})
    ->Assert.dict
    ->Assert.entry("todo-1", item("todo-1", "Buy milk", 1))

    let cached = items.array({status: "active"})
    expect(cached).toEqual(Loaded([item("todo-1", "Buy milk", 1)]))
    expect(items.get("todo-1")).toEqual(Loaded(item("todo-1", "Buy milk", 1)))
    expect(count.contents).toBe(1)
  })

  it("should update derived query views when cached objects change", async () => {
    let count = ref(0)
    let api: Papabase.api<item, itemQuery> = {
      fetch: async _key => {
        count := count.contents + 1
        await sleep()
        [item("todo-1", "Buy milk", count.contents)]
      },
      upsert: async (_, _) => (),
    }

    let items = Papabase.make("items", item => item.id, api)

    ignore(items.array({status: "active"}))
    await sleep()

    let array = items.array({status: "active"})->Assert.array
    let dict = items.dict({status: "active"})->Assert.dict

    Assert.first(array, item("todo-1", "Buy milk", 1))
    Assert.entry(dict, "todo-1", item("todo-1", "Buy milk", 1))

    ignore(items.array({status: "refresh"}))
    await sleep()

    Assert.first(array, item("todo-1", "Buy milk", 2))
    Assert.entry(dict, "todo-1", item("todo-1", "Buy milk", 2))
  })

  it("should use sorted JSON keys for structured queries", async () => {
    let count = ref(0)
    let api: Papabase.api<item, sortedQuery> = {
      fetch: async _query => {
        count := count.contents + 1
        await sleep()
        [item("todo-1", "Buy milk", count.contents)]
      },
      upsert: async (_, _) => (),
    }

    let items = Papabase.make("items", item => item.id, api)

    expect(items.array({status: "active", owner: "me"})).toEqual(Loading)
    await sleep()

    let sameQuery: reversedQuery = {owner: "me", status: "active"}
    expect(items.array((sameQuery :> sortedQuery))).toEqual(Loaded([item("todo-1", "Buy milk", 1)]))
    expect(count.contents).toBe(1)
  })

  it("should update local cache and trigger remote upsert", async () => {
    let upserted = ref([])
    let api: Papabase.api<item, itemQuery> = {
      fetch: async _q => {
        await sleep()
        [item("todo-1", "Buy milk", 1)]
      },
      upsert: async (id, value) => {
        upserted := [(id, value), ...upserted.contents]
      },
    }

    let items = Papabase.make("items", item => item.id, api)
    ignore(items.array({status: "active"}))
    await sleep()

    let array = items.array({status: "active"})->Assert.array
    Assert.first(array, item("todo-1", "Buy milk", 1))

    items.upsert("todo-1", item("todo-1", "Buy bread", 5))

    expect(items.get("todo-1")).toEqual(Loaded(item("todo-1", "Buy bread", 5)))
    Assert.first(array, item("todo-1", "Buy bread", 5))

    await sleep()
    expect(upserted.contents).toEqual([("todo-1", item("todo-1", "Buy bread", 5))])
  })

  it("should invalidate matching live queries from local writes", async () => {
    let activeCount = ref(0)
    let doneCount = ref(0)
    let api: Papabase.api<item, itemQuery> = {
      fetch: async q => {
        await sleep()
        switch q.status {
        | "active" => {
            activeCount := activeCount.contents + 1
            [item("todo-1", "active", activeCount.contents)]
          }
        | _ => {
            doneCount := doneCount.contents + 1
            [item("todo-2", "done", doneCount.contents)]
          }
        }
      },
      upsert: async (_, _) => (),
    }

    let items = Papabase.make(
      "items",
      item => item.id,
      api,
      ~invalidates=(query, item) => query.status == item.name,
    )

    watch(() => items.array({status: "active"}), _ => ())
    watch(() => items.array({status: "done"}), _ => ())
    await sleep()

    let active = items.array({status: "active"})->Assert.array
    let done = items.array({status: "done"})->Assert.array
    Assert.first(active, item("todo-1", "active", 1))
    Assert.first(done, item("todo-2", "done", 1))

    items.upsert("todo-1", item("todo-1", "active", 99))

    Assert.first(active, item("todo-1", "active", 99))
    await sleep()

    Assert.first(active, item("todo-1", "active", 2))
    Assert.first(done, item("todo-2", "done", 1))
    expect(activeCount.contents).toBe(2)
    expect(doneCount.contents).toBe(1)
  })

  it("should sync live objects without triggering remote upsert", async () => {
    let activeCount = ref(0)
    let upserted = ref([])
    let api: Papabase.api<item, itemQuery> = {
      fetch: async _q => {
        activeCount := activeCount.contents + 1
        await sleep()
        [item("todo-1", "active", activeCount.contents)]
      },
      upsert: async (id, value) => {
        upserted := [(id, value), ...upserted.contents]
      },
    }

    let items = Papabase.make(
      "items",
      item => item.id,
      api,
      ~invalidates=(query, item) => query.status == item.name,
    )

    watch(() => items.array({status: "active"}), _ => ())
    await sleep()

    let active = items.array({status: "active"})->Assert.array
    Assert.first(active, item("todo-1", "active", 1))

    items.sync(item("todo-1", "active", 99))

    expect(items.get("todo-1")).toEqual(Loaded(item("todo-1", "active", 99)))
    Assert.first(active, item("todo-1", "active", 99))

    await sleep()

    Assert.first(active, item("todo-1", "active", 2))
    expect(upserted.contents).toEqual([])
    expect(activeCount.contents).toBe(2)
  })

  it("should refresh live stale queries in the background", async () => {
    let count = ref(0)
    let clock = ref(0.0)
    let api: Papabase.api<item, itemQuery> = {
      fetch: async _q => {
        count := count.contents + 1
        let n = count.contents
        await sleep()
        [item("todo-1", "Buy milk", n)]
      },
      upsert: async (_, _) => (),
    }

    let items = Papabase.make(
      "items",
      item => item.id,
      api,
      ~stale=30.0,
      ~gc=300.0,
      ~now=() => clock.contents,
    )

    watch(() => items.array({status: "active"}), _ => ())
    await sleep()

    Assert.first(items.array({status: "active"})->Assert.array, item("todo-1", "Buy milk", 1))

    clock := 31.0
    items.tick()
    await sleep()

    Assert.first(items.array({status: "active"})->Assert.array, item("todo-1", "Buy milk", 2))
    expect(count.contents).toBe(2)
  })

  it("should evict idle queries after gc and purge unreferenced cache", async () => {
    let clock = ref(0.0)
    let api: Papabase.api<item, tagQuery> = {
      fetch: async q => {
        await sleep()
        switch q.tag {
        | "a" => [item("a-1", "A", 1)]
        | _ => [item("b-1", "B", 1)]
        }
      },
      upsert: async (_, _) => (),
    }

    let items = Papabase.make(
      "items",
      item => item.id,
      api,
      ~stale=30.0,
      ~gc=300.0,
      ~now=() => clock.contents,
    )

    ignore(items.array({tag: "a"}))
    watch(() => items.array({tag: "b"}), _ => ())
    await sleep()

    expect(items.get("a-1")).toEqual(Loaded(item("a-1", "A", 1)))
    expect(items.get("b-1")).toEqual(Loaded(item("b-1", "B", 1)))

    items.tick()

    clock := 301.0
    items.tick()

    expect(items.get("a-1")).toEqual(NotFound)
    expect(items.get("b-1")).toEqual(Loaded(item("b-1", "B", 1)))
  })

  it("should keep cache entries shared between queries", async () => {
    let clock = ref(0.0)
    let api: Papabase.api<item, tagQuery> = {
      fetch: async _q => {
        await sleep()
        [item("shared", "S", 1)]
      },
      upsert: async (_, _) => (),
    }

    let items = Papabase.make(
      "items",
      item => item.id,
      api,
      ~stale=30.0,
      ~gc=300.0,
      ~now=() => clock.contents,
    )

    watch(() => items.array({tag: "a"}), _ => ())
    ignore(items.array({tag: "b"}))
    await sleep()

    expect(items.get("shared")).toEqual(Loaded(item("shared", "S", 1)))

    items.tick()
    clock := 301.0
    items.tick()

    expect(items.get("shared")).toEqual(Loaded(item("shared", "S", 1)))
  })
})
