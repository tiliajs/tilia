open VitestBdd
open Tilia

module H = TiliaQueryTestHelpers
@tag("state")
type loadable<'a> = H.loadable<'a> =
  | @as("loading") Loading
  | @as("loaded") Loaded({data: 'a})
  | @as("notFound") NotFound
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
  let remembered: dict<loadable<array<H.item>>> = Dict.make()
  let switchable = ref(None)
  let has = (keys: array<string>, key) => keys->Array.some(v => v == key)
  let queryKey = status => "{\"status\":\"" ++ status ++ "\"}"

  step("tasks are", table => {
    let rows: array<taskRow> = toRecords(table)
    H.seed(w, rows->Array.map(task))
  })

  step("network is {string}", mode =>
    switch mode {
    | "online" => H.setNetwork(w, true)
    | "offline" => H.setNetwork(w, false)
    | _ => failwith("Unknown network mode")
    }
  )

  step("network becomes {string}", mode =>
    switch mode {
    | "online" => H.setNetwork(w, true)
    | "offline" => H.setNetwork(w, false)
    | _ => failwith("Unknown network mode")
    }
  )

  step("remote write delivery is {string}", mode =>
    switch mode {
    | "paused" => H.pauseWrites(w, true)
    | "live" => H.pauseWrites(w, false)
    | _ => failwith("Unknown write delivery mode")
    }
  )

  step("next upsert for task {string} conflicts with status {string} count {number}", (id, status, count) =>
    H.queueConflict(w, id, status, count)
  )

  step("next upsert for task {string} is rejected with {string}", (id, message) =>
    H.queueRejected(w, id, message)
  )

  step("next upsert for task {string} fails offline", id => H.queueOffline(w, id))

  step("next remove for task {string} conflicts with status {string} count {number}", (id, status, count) =>
    H.queueConflict(w, id, status, count)
  )

  step("next remove for task {string} is rejected with {string}", (id, message) =>
    H.queueRejected(w, id, message)
  )

  step("next fetch for {string} tasks is covered", status => H.queueCoveredFetch(w, status))

  step("next fetch for {string} tasks fails with {string}", (status, message) =>
    H.queueFailFetch(w, status, message)
  )

  step("the clock advances {number} seconds", seconds => {
    w.clock := w.clock.contents +. Float.fromInt(seconds)
  })

  step(
    "local store has task {string} with status {string} count {number} marked {string}",
    (id, status, count, mark) => H.seedLocal(w, id, status, count, mark == "dirty"),
  )

  step("local store has a deleted task {string} with status {string} count {number}", (
    id,
    status,
    count,
  ) => H.seedLocalTombstone(w, id, status, count))

  step("the app restarts", () => H.restart(w))

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

  step("I open one {string} task", status => {
    watch(() => w.items.one({status: status}), _ => ())
  })

  step("I observe tasks through switchable filter starting at {string}", status => {
    let (state, _) = signal(status)
    switchable := Some(state)
    watch(() => w.items.array({status: state.value}), _ => ())
  })

  step("I switch observed filter to {string}", status =>
    switch switchable.contents {
    | Some(state) => state.value = status
    | None => failwith("No switchable observer")
    }
  )

  step("query key for {string} should be live", status => {
    let canopy = w.items.canopy()
    expect(has(canopy.live, queryKey(status))).toBe(true)
  })

  step("query key for {string} should be idle", status => {
    let canopy = w.items.canopy()
    expect(has(canopy.live, queryKey(status))).toBe(false)
  })

  step("the one {string} task should be {string} with count {number}", (status, id, count) =>
    expect(w.items.one({status: status})).toEqual(Loaded({data: item(id, status, count)}))
  )

  step("the one {string} task should be not found", status =>
    expect(w.items.one({status: status})).toEqual(NotFound)
  )

  step("I edit task {string} to status {string} count {number}", (id, status, count) => {
    w.items.upsert(item(id, status, count))
  })

  step("I delete task {string} with status {string} count {number}", (id, status, count) => {
    w.items.remove(item(id, status, count))
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

  step("I emit from held upsert channel {number} with count {number}", (position, count) => {
    let index = if position <= 0 {0} else {position - 1}
    H.emitHeldWrite(w, index, count)
  })

  step("I emit from held remove channel {number}", position => {
    let index = if position <= 0 {0} else {position - 1}
    H.emitHeldRemove(w, index)
  })

  step("{string} tasks should be", (status, table) => {
    let rows: array<taskRow> = toRecords(table)
    expect(w.items.array({status: status})).toEqual(Loaded({data: rows->Array.map(task)}))
  })

  step("no {string} tasks should remain", status =>
    expect(w.items.array({status: status})).toEqual(Loaded({data: []}))
  )

  step("task {string} in cache should be status {string} count {number}", (id, status, count) =>
    expect(w.items.get(id)).toEqual(Loaded({data: item(id, status, count)}))
  )

  step("task {string} in cache should be absent", id =>
    expect(w.items.get(id)).toEqual(NotFound)
  )

  step("remote task {string} should be status {string} count {number}", (id, status, count) =>
    expect(H.remoteTask(w, id)).toEqual(item(id, status, count))
  )

  step("remote task {string} should be absent", id =>
    expect(H.remoteRow(w, id)->Option.isNone).toBe(true)
  )

  step("local task {string} should be absent", id =>
    expect(H.localRow(w, id)->Option.isNone).toBe(true)
  )

  step(
    "local task {string} should be a dirty tombstone with status {string} count {number}",
    (id, status, count) => {
      let row = H.localTask(w, id)
      expect(row.item).toEqual(item(id, status, count))
      expect(row.dirty).toBe(true)
      expect(row.deleted).toBe(true)
    },
  )

  step(
    "local task {string} should be status {string} count {number} and {string}",
    (id, status, count, mark) => {
      let row = H.localTask(w, id)
      expect(row.item).toEqual(item(id, status, count))
      expect(row.dirty).toBe(mark == "dirty")
    },
  )

  step("local fetch calls should be {number}", expected =>
    expect(H.localFetchCount(w)).toBe(expected)
  )

  step("the {string} tasks view should be stable", status =>
    expect(w.items.array({status: status})).toBe(w.items.array({status: status}))
  )

  step("I remember the {string} tasks view", status =>
    Dict.set(remembered, status, w.items.array({status: status}))
  )

  step("the {string} tasks view should be unchanged", status =>
    switch Dict.get(remembered, status) {
    | Some(view) => expect(w.items.array({status: status})).toBe(view)
    | None => failwith("No remembered view")
    }
  )

  step("synced remote writes should be {number}", expected =>
    expect(w.remote.syncedWrites.contents->Array.length).toBe(expected)
  )

  step("remote upsert calls should be {number}", expected =>
    expect(w.remote.upsertCalls.contents).toBe(expected)
  )

  step("remote remove calls should be {number}", expected =>
    expect(w.remote.removeCalls.contents).toBe(expected)
  )

  step("pending writes should be {number}", expected =>
    expect(w.items.status.pending).toBe(expected)
  )

  step("rejected writes on status should be {number}", expected =>
    expect(w.items.status.rejected->Array.length).toBe(expected)
  )

  step("rejection {number} message should be {string}", (position, message) => {
    let index = if position <= 0 {0} else {position - 1}
    switch w.items.status.rejected[index] {
    | Some(rejection) => expect(rejection.message).toBe(message)
    | None => failwith("Expected rejection on status")
    }
  })

  step("I dismiss rejections", () => w.items.dismiss())

  step("I dispose the query state", () => w.items.dispose())

  step("I clear the query state", () => w.items.clear())

  step("last fetch error should be {string}", message =>
    switch w.items.status.error {
    | Some(error) => expect(error.message).toBe(message)
    | None => failwith("Expected fetch error on status")
    }
  )

  step("last fetch error should be empty", () =>
    expect(w.items.status.error->Option.isNone).toBe(true)
  )

  step("rejected remote writes should be {number}", expected =>
    expect(w.remote.rejectedWrites.contents).toBe(expected)
  )

  step("held upsert channels should be {number}", expected =>
    expect(H.heldWrites(w)).toBe(expected)
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
