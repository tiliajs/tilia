// A `Kv` over IndexedDB, for `Store`'s `persist`.
//
// One object store, compound key `[tag, key]`, so a tag is a range: reading
// everything under one, or listing its keys, never touches the rest. Rows,
// query records and the outbox all live here as strings — what they mean is
// the store's business, not this file's.
//
// Two things this has to get right, and they are why it is more than the
// bindings below:
//
// - Nothing can be asked of a database that is not open yet, and the store
//   asks immediately: the outbox replay happens in its own constructor. So a
//   call made before the open waits for it, and a database that never opens
//   answers with nothing rather than throwing into a caller with no way to
//   care.
// - A fresh answer writes one entry per row. A transaction each would be the
//   slowest thing the application does, so writes accumulate and go out
//   together. A read issues that transaction before its own, and IndexedDB
//   serializes overlapping scopes in creation order — so a read can never
//   answer without a row the store believes it has already written.

// `Dict` and `Arr` are the shadowing bindings the whole package reads
// through; the shadow is the point.
@@warning("-44")
open TiliaQuerySchema

// === The IndexedDB surface this needs, and nothing else

type factory
type database
type names
type tx
type store
type range

/** One entry, as it is kept: the compound key is its own two fields. */
type row = {tag: string, key: string, value: string}

type storeOptions = {keyPath: array<string>}

/** A request answers on `onsuccess`, or fails on `onerror`. */
type request<'a>

@send external openDatabase: (factory, string, float) => request<database> = "open"
@get external result: request<'a> => 'a = "result"
@get external requestError: request<'a> => JsError.t = "error"
@set external onsuccess: (request<'a>, unit => unit) => unit = "onsuccess"
@set external onerror: (request<'a>, unit => unit) => unit = "onerror"
@set external onupgradeneeded: (request<database>, unit => unit) => unit = "onupgradeneeded"

@get external objectStoreNames: database => names = "objectStoreNames"
@send external contains: (names, string) => bool = "contains"
@send external createObjectStore: (database, string, storeOptions) => unit = "createObjectStore"
@send external transaction: (database, string, string) => tx = "transaction"

@send external objectStore: (tx, string) => store = "objectStore"
@get external txError: tx => JsError.t = "error"
@set external onabort: (tx, unit => unit) => unit = "onabort"
@set external ontxerror: (tx, unit => unit) => unit = "onerror"

@send external getEntry: (store, array<string>) => request<nullable<row>> = "get"
@send external getAll: (store, range) => request<array<row>> = "getAll"
@send external getAllKeys: (store, range) => request<array<array<string>>> = "getAllKeys"
@send external put: (store, row) => unit = "put"
@send external deleteEntry: (store, array<string>) => unit = "delete"

@scope("IDBKeyRange") @val external bound: (array<JSON.t>, array<JSON.t>) => range = "bound"

@val external queueMicrotask: (unit => unit) => unit = "queueMicrotask"

// Reading an undeclared global throws where reading an undefined property
// does not, and there is no IndexedDB outside a browser.
let indexedDb: unit => nullable<factory> = %raw(`
function indexedDb() {
  return typeof indexedDB === "undefined" ? undefined : indexedDB;
}`)

// `[tag]` sorts before every `[tag, key]`, and an array sorts after every
// string, so `[tag, []]` closes the range whatever the keys are.
let tagRange = tag => bound([JSON.String(tag)], [JSON.String(tag), JSON.Array([])])

// === The keyspace

/** A queued write. `value` absent is a delete. */
type write = {wtag: string, wkey: string, wvalue: nullable<string>}

type config = {
  /** Database name. */
  name: string,
  /** Object store name. Default: `"entries"`. */
  store?: string,
  /** Database version. Default: 1. */
  version?: float,
  /**
   * A database that will not open, a transaction that aborts. Reads still
   * answer — with nothing — and writes are dropped, because persistence is
   * command-only and the store has no way to care. This is how you find out.
   */
  onError?: JsError.t => unit,
}

let make = ({name, ?store, ?version, ?onError}: config): TiliaQueryStore.Kv.t => {
  let storeName = switch store {
  | Some(store) => store
  | None => "entries"
  }
  let version = switch version {
  | Some(version) => version
  | None => 1.0
  }
  let report = error =>
    switch onError {
    | Some(onError) => onError(error)
    | None => ()
    }

  let opened: ref<nullable<database>> = ref(Nullable.Null)
  // Set when the database will never open: from then on, answering with
  // nothing is the answer.
  let broken = ref(false)
  // Calls that arrived before the open. Each is handed the database, or
  // nothing if there will never be one.
  let waiting: array<nullable<database> => unit> = []

  let pending = ref(Dict.make())
  let scheduled = ref(false)

  // Everything the store asked for since the last flush, one per entry.
  let flush = database => {
    let writes = pending.contents->Dict.values
    if writes->Array.length > 0 {
      pending := Dict.make()
      let tx = database->transaction(storeName, "readwrite")
      let table = tx->objectStore(storeName)
      writes->Array.forEach(write =>
        switch write.wvalue {
        | Value(value) => table->put({tag: write.wtag, key: write.wkey, value})
        | Null | Undefined => table->deleteEntry([write.wtag, write.wkey])
        }
      )
      tx->ontxerror(() => report(tx->txError))
      tx->onabort(() => report(tx->txError))
    }
  }

  // A job runs against the open database, or against nothing.
  let withDatabase = job =>
    switch opened.contents {
    | Value(database) => job(Nullable.Value(database))
    | Null | Undefined =>
      if broken.contents {
        job(Nullable.Null)
      } else {
        waiting->Array.push(job)
      }
    }

  let release = database => {
    let jobs = waiting->Array.copy
    waiting->Array.splice(~start=0, ~remove=waiting->Array.length, ~insert=[])
    jobs->Array.forEach(job => job(database))
  }

  switch indexedDb() {
  | Value(factory) =>
    let request = factory->openDatabase(name, version)
    request->onupgradeneeded(() => {
      let database = request->result
      if !(database->objectStoreNames->contains(storeName)) {
        database->createObjectStore(storeName, {keyPath: ["tag", "key"]})
      }
    })
    request->onsuccess(() => {
      let database = request->result
      opened := Value(database)
      release(Nullable.Value(database))
    })
    request->onerror(() => {
      broken := true
      report(request->requestError)
      release(Nullable.Null)
    })
  | Null | Undefined =>
    broken := true
    report(JsError.make("IndexedDB is not available"))
  }

  // A read flushes first, so it cannot answer without a row the store
  // believes it wrote: IndexedDB serializes overlapping scopes in the order
  // the transactions were created.
  let reading = (job, answer) =>
    withDatabase(database =>
      switch database {
      | Value(database) =>
        flush(database)
        job(database->transaction(storeName, "readonly")->objectStore(storeName))
      | Null | Undefined => answer([])
      }
    )

  {
    get: (~tag, ~keys=?, ~set) => reading(table =>
        switch keys {
        | None =>
          let request = table->getAll(tagRange(tag))
          request->onsuccess(() => set(request->result->Array.map(row => row.value)))
          request->onerror(() => {
            report(request->requestError)
            set([])
          })
        | Some(keys) =>
          // In the order asked for: a query record's ids are its order. One
          // slot per key, filled where the entry was there.
          let found: array<nullable<string>> = keys->Array.map(_ => Nullable.Null)
          let outstanding = ref(keys->Array.length)
          let settle = () => {
            outstanding := outstanding.contents - 1
            if outstanding.contents === 0 {
              set(
                found->Array.filterMap(value =>
                  switch value {
                  | Value(value) => Some(value)
                  | Null | Undefined => None
                  }
                ),
              )
            }
          }
          if keys->Array.length === 0 {
            set([])
          } else {
            keys->Array.forEachWithIndex((key, index) => {
              let request = table->getEntry([tag, key])
              request->onsuccess(
                () => {
                  switch request->result {
                  | Value(row) => found->Array.set(index, Nullable.Value(row.value))
                  | Null | Undefined => ()
                  }
                  settle()
                },
              )
              request->onerror(
                () => {
                  report(request->requestError)
                  settle()
                },
              )
            })
          }
        }
      , set),
    keys: (~tag, ~set) => reading(table => {
        let request = table->getAllKeys(tagRange(tag))
        request->onsuccess(() =>
          set(
            request
            ->result
            ->Array.filterMap(
              key =>
                switch key->Arr.at(1) {
                | Value(key) => Some(key)
                | Null | Undefined => None
                },
            ),
          )
        )
        request->onerror(() => {
          report(request->requestError)
          set([])
        })
      }, set),
    set: (~tag, ~key, value) => {
      // A tag never contains a NUL, so this cannot collide with another.
      pending.contents->Dict.set(
        tag ++ " " ++ key,
        {
          wtag: tag,
          wkey: key,
          wvalue: switch value {
          | Some(value) => Nullable.Value(value)
          | None => Nullable.Null
          },
        },
      )

      // The batch is one transaction because `flush` takes everything
      // pending, not because of this flag: without it the writes still go out
      // together, they just queue a job each. A cheap guard, and nothing
      // tests it.
      if !scheduled.contents {
        scheduled := true
        queueMicrotask(() => {
          scheduled := false
          withDatabase(database =>
            switch database {
            | Value(database) => flush(database)
            | Null | Undefined => ()
            }
          )
        })
      }
    },
  }
}
