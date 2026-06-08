open VitestBdd
open Tilia

module H = TiliaQueryTestHelpers
type loadable<'a> = H.loadable<'a> = Loading | Loaded('a) | NotFound
let item = H.item
type taskRow = {id: string, status: string, count: string}

let parse = value =>
  switch Int.fromString(value) {
  | Some(count) => count
  | None => failwith("Expected number")
  }

let task = (row: taskRow) => item(row.id, row.status, parse(row.count))

given("a task world", ({step}, _) => {
  let w = H.makeWorld()

  step("tasks are", table => {
    let rows: array<taskRow> = toRecords(table)
    H.seed(w, rows->Array.map(task))
  })

  step("network is {string}", mode =>
    switch mode {
    | "online" => w.remote.online := true
    | "offline" => w.remote.online := false
    | _ => failwith("Unknown network mode")
    }
  )

  step("network becomes {string}", mode =>
    switch mode {
    | "online" => {
        w.remote.online := true
        let queued = w.remote.pendingWrites.contents
        w.remote.syncPending()
        queued->Array.forEach(w.items.sync)
        w.items.tick()
      }
    | "offline" => w.remote.online := false
    | _ => failwith("Unknown network mode")
    }
  )

  step("I open {string} tasks", list =>
    switch list {
    | "active" => {
        watch(() => w.items.array({status: "active"}), _ => ())
      }
    | "done" => {
        watch(() => w.items.array({status: "done"}), _ => ())
      }
    | "active and done" => {
        watch(() => w.items.array({status: "active"}), _ => ())
        watch(() => w.items.array({status: "done"}), _ => ())
      }
    | _ => failwith("Unknown tasks list")
    }
  )

  step("I edit task {string} to status {string} count {number}", (id, status, count) => {
    w.items.upsert(item(id, status, count))
  })

  step("I sync pending writes", () => {
    let queued = w.remote.pendingWrites.contents
    w.remote.syncPending()
    queued->Array.forEach(w.items.sync)
    w.items.tick()
  })

  step("I run tick for {string} tasks after {number} seconds", (target, seconds) => {
    w.clock := w.clock.contents +. Float.fromInt(seconds)
    switch target {
    | "active" | "done" => w.items.tick()
    | "active and done" => w.items.tick()
    | _ => failwith("Unknown tick target")
    }
  })

  step("I emit from active fetch channel {number} with count {number}", (position, count) => {
    let index = if position <= 0 {0} else {position - 1}
    H.emitActiveChannel(w, index, count)
  })

  step("{string} tasks should be", (status, table) => {
    let rows: array<taskRow> = toRecords(table)
    expect(w.items.array({status: status})).toEqual(Loaded(rows->Array.map(task)))
  })

  step("no {string} tasks should remain", status =>
    expect(w.items.array({status: status})).toEqual(Loaded([]))
  )

  step("task {string} in cache should be status {string} count {number}", (id, status, count) =>
    expect(w.items.get(id)).toEqual(Loaded(item(id, status, count)))
  )

  step("remote task {string} should be status {string} count {number}", (id, status, count) =>
    expect(H.remoteTask(w, id)).toEqual(item(id, status, count))
  )

  step("pending sync writes should be {number}", expected =>
    expect(w.remote.pendingWrites.contents->Array.length).toBe(expected)
  )

  step("synced remote writes should be {number}", expected =>
    expect(w.remote.syncedWrites.contents->Array.length).toBe(expected)
  )

  step("{string} fetch calls should be {number}", (name, expected) =>
    expect(
      switch name {
      | "active" => w.remote.activeFetches.contents
      | "done" => w.remote.doneFetches.contents
      | "offline" => w.remote.offlineFetches.contents
      | _ => failwith("Unknown fetch metric")
      },
    ).toBe(expected)
  )
})
