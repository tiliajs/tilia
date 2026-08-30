// The smallest IndexedDB that answers what `TiliaQueryIndexedDb` asks: an
// open with an upgrade, one object store with a compound key path, `get`,
// `getAll`, `getAllKeys`, `put`, `delete`, and key ranges over `[tag, key]`.
//
// Requests answer on a macrotask, the way a real one does — which is the
// point: it is what makes "waits for the open" and "flushed before a read"
// observable rather than assumed.

// The fake agrees with the keyspace by shape, not by type: it installs plain
// objects where a browser would have put IndexedDB's, and the bindings reach
// them exactly as they reach the real thing. So everything here is typed on
// its own terms.

/** The two globals a browser would have. Installing them is what makes this
 a fake environment rather than an injected dependency. */
let install: ('a, 'b) => unit = %raw(`
function install(factory, keyRange) {
  globalThis.indexedDB = factory;
  globalThis.IDBKeyRange = keyRange;
}`)

let uninstall: unit => unit = %raw(`
function uninstall() {
  delete globalThis.indexedDB;
  delete globalThis.IDBKeyRange;
}`)

let later: (unit => unit) => unit = %raw(`
function later(fn) {
  setTimeout(fn, 0);
}`)

type row = {tag: string, key: string, value: string}

type storeOptions = {keyPath: array<string>}

type request<'a> = {
  mutable onsuccess: unit => unit,
  mutable onerror: unit => unit,
  mutable onupgradeneeded: unit => unit,
  mutable result: 'a,
  mutable error: JsError.t,
}

type range = {lower: array<JSON.t>, upper: array<JSON.t>}

type names = {contains: string => bool}

type table = {
  get: array<string> => request<nullable<row>>,
  getAll: range => request<array<row>>,
  getAllKeys: range => request<array<array<string>>>,
  put: row => unit,
  @as("delete") remove: array<string> => unit,
}

type tx = {
  objectStore: string => table,
  mutable onerror: unit => unit,
  mutable onabort: unit => unit,
  mutable error: JsError.t,
}

type database = {
  objectStoreNames: names,
  createObjectStore: (string, storeOptions) => unit,
  transaction: (string, string) => tx,
}

type factory = {@as("open") openDatabase: (string, float) => request<database>}

/** Test control over the database the adaptor opened. */
type t = {
  /** How many transactions it has asked for. */
  mutable transactions: int,
  /** While set, every transaction aborts. */
  mutable failing: bool,
}

// IndexedDB's key order, for the keys this store uses: a string sorts before
// an array, and arrays compare element by element.
let rec compare = (a: JSON.t, b: JSON.t) =>
  switch (a, b) {
  | (String(a), String(b)) =>
    if a < b {
      -1
    } else if a > b {
      1
    } else {
      0
    }
  | (String(_), Array(_)) => -1
  | (Array(_), String(_)) => 1
  | (Array(a), Array(b)) => compareAll(a, b)
  | _ => 0
  }
and compareAll = (a, b) => {
  let result = ref(0)
  let index = ref(0)
  while result.contents === 0 && index.contents < Math.Int.min(a->Array.length, b->Array.length) {
    result := compare(a->Array.getUnsafe(index.contents), b->Array.getUnsafe(index.contents))
    index := index.contents + 1
  }
  if result.contents !== 0 {
    result.contents
  } else {
    a->Array.length - b->Array.length
  }
}

let asKey = (key: array<string>): JSON.t => JSON.Array(key->Array.map(part => JSON.String(part)))

let within = (range: range, key) =>
  compare(JSON.Array(range.lower), asKey(key)) <= 0 &&
    compare(asKey(key), JSON.Array(range.upper)) <= 0

let keyRange = {
  "bound": (lower, upper) => {lower, upper},
}

let answering = (produce: unit => 'a): request<'a> => {
  let request = {
    onsuccess: () => (),
    onerror: () => (),
    onupgradeneeded: () => (),
    result: %raw(`undefined`),
    error: JsError.make("not failed"),
  }
  later(() => {
    request.result = produce()
    request.onsuccess()
  })
  request
}

/**
 * A fake IndexedDB, and the handle a scenario drives it by. `failOpen` makes
 * the database refuse to open at all.
 */
let make = (~failOpen=false, ()): t => {
  let control = {transactions: 0, failing: false}
  let rows: dict<row> = Dict.make()
  let id = (key: array<string>) => JSON.stringifyAny(key)->Option.getOr("")

  let sorted = () =>
    rows
    ->Dict.toArray
    ->Array.toSorted(((a, _), (b, _)) =>
      Int.toFloat(compare(JSON.parseOrThrow(a), JSON.parseOrThrow(b)))
    )
    ->Array.map(((key, row)) => (JSON.parseOrThrow(key), row))

  let matching = (range: range) => {
    sorted()->Array.filter(((key, _)) =>
      switch key {
      | JSON.Array(parts) =>
        within(
          range,
          parts->Array.filterMap(part =>
            switch part {
            | JSON.String(part) => Some(part)
            | _ => None
            }
          ),
        )
      | _ => false
      }
    )
  }

  // A transaction's writes land together when it completes, and nowhere at
  // all when it aborts — which is the whole difference between the two.
  let tableFor = (writes: array<unit => unit>) => {
    get: key =>
      answering(() =>
        switch rows->Dict.get(id(key)) {
        | Some(row) => Nullable.Value(row)
        | None => Nullable.Null
        }
      ),
    getAll: range => answering(() => matching(range)->Array.map(((_, row)) => row)),
    getAllKeys: range =>
      answering(() =>
        matching(range)->Array.map(((key, _)) =>
          switch key {
          | JSON.Array(parts) =>
            parts->Array.filterMap(
              part =>
                switch part {
                | JSON.String(part) => Some(part)
                | _ => None
                },
            )
          | _ => []
          }
        )
      ),
    put: row => writes->Array.push(() => rows->Dict.set(id([row.tag, row.key]), row)),
    remove: key => writes->Array.push(() => rows->Dict.delete(id(key))),
  }

  let database = {
    objectStoreNames: {contains: _ => true},
    createObjectStore: (_, _) => (),
    transaction: (_, _) => {
      control.transactions = control.transactions + 1
      let writes = []
      let tx = {
        objectStore: _ => tableFor(writes),
        onerror: () => (),
        onabort: () => (),
        error: JsError.make("transaction aborted"),
      }
      later(() =>
        if control.failing {
          tx.onabort()
        } else {
          writes->Array.forEach(write => write())
        }
      )
      tx
    },
  }

  let factory = {
    openDatabase: (_, _) => {
      let request = {
        onsuccess: () => (),
        onerror: () => (),
        onupgradeneeded: () => (),
        result: database,
        error: JsError.make("cannot open"),
      }
      later(() =>
        if failOpen {
          request.onerror()
        } else {
          request.onupgradeneeded()
          request.onsuccess()
        }
      )
      request
    },
  }

  install(factory, keyRange)
  control
}
