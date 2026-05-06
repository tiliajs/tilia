open VitestBdd
open Tilia
open TiliaQuery

let sleep: unit => promise<unit> = async () =>
  %raw(`new Promise(resolve => setTimeout(resolve, 10))`)

type item = {id: string, name: string, count: int}

let item = (id, name, count) => {id, name, count}

// Fake Supabase adaptor to show how to adapt @tilia/query to any remote source.
module Sullybase = {
  type api<'a> = {
    fetch: string => promise<array<'a>>,
  }

  let make = (_table, id, api) => TiliaQuery.make(~id, ~fetch=api.fetch, ())
}

describe("TiliaQuery", () => {
  it("should cache query data", async () => {
    let count = ref(0)
    let api: Sullybase.api<item> = {
      fetch: async _key => {
        count := count.contents + 1
        await sleep()
        [item("todo-1", "Buy milk", count.contents)]
      },
    }

    let items = Sullybase.make("items", item => item.id, api)
    let toArray = TiliaQuery.toArray(items)
    let list = derived(() => items.find("list"))

    expect(list.value).toEqual(Loading)

    await sleep()

    expect(list.value).toEqual(Loaded(["todo-1"]))
    expect(list.value->toArray).toEqual(Loaded([item("todo-1", "Buy milk", 1)]))

    let cached = derived(() => items.find("list"))
    expect(cached.value).toEqual(Loaded(["todo-1"]))
    expect(cached.value->toArray).toEqual(Loaded([item("todo-1", "Buy milk", 1)]))
    expect(count.contents).toBe(1)
  })
})
