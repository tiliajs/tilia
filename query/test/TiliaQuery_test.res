open VitestBdd
open Tilia
open TiliaQuery

let sleep: unit => promise<unit> = async () =>
  %raw(`new Promise(resolve => setTimeout(resolve, 10))`)

type item = {id: string, name: string, count: int}
type itemQuery = {status: string}
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
module Sullybase = {
  type api<'a, 'query> = {
    fetch: 'query => promise<array<'a>>,
  }

  let make = (_table, id, api) => TiliaQuery.make(~id, ~fetch=api.fetch, ())
}

describe("TiliaQuery", () => {
  it("should cache query data", async () => {
    let count = ref(0)
    let api: Sullybase.api<item, itemQuery> = {
      fetch: async query => {
        expect(query.status).toBe("active")
        count := count.contents + 1
        await sleep()
        [item("todo-1", "Buy milk", count.contents)]
      },
    }

    let items = Sullybase.make("items", item => item.id, api)
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
    let api: Sullybase.api<item, itemQuery> = {
      fetch: async _key => {
        count := count.contents + 1
        await sleep()
        [item("todo-1", "Buy milk", count.contents)]
      },
    }

    let items = Sullybase.make("items", item => item.id, api)

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
    let api: Sullybase.api<item, sortedQuery> = {
      fetch: async _query => {
        count := count.contents + 1
        await sleep()
        [item("todo-1", "Buy milk", count.contents)]
      },
    }

    let items = Sullybase.make("items", item => item.id, api)

    expect(items.array({status: "active", owner: "me"})).toEqual(Loading)
    await sleep()

    let sameQuery: reversedQuery = {owner: "me", status: "active"}
    expect(items.array((sameQuery :> sortedQuery))).toEqual(Loaded([item("todo-1", "Buy milk", 1)]))
    expect(count.contents).toBe(1)
  })
})
