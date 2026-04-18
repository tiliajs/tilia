open VitestBdd
open Tilia

%%raw(`function throwString(e) { throw new Error(e) }`)

external throw: 'a => 'b = "throwString"

module TestObject = {
  type t
  let make: unit => t = %raw(`() => ({})`)
  external get: (t, string) => string = "Reflect.get"
  external set: (t, string, string) => unit = "Reflect.set"
  external remove: (t, string) => unit = "Reflect.deleteProperty"
  external keys: t => array<string> = "Object.keys"
}

module AnyObject = {
  type descriptor<'a> = {writable: bool, value: 'a}
  external get: ('a, string) => 'b = "Reflect.get"
  external set: ('a, string, 'b) => bool = "Reflect.set"
  external deleteProperty: ('a, string) => unit = "Reflect.deleteProperty"
  external getOwnPropertyDescriptor: ('a, string) => nullable<descriptor<'b>> =
    "Object.getOwnPropertyDescriptor"
  external defineProperty: ('a, string, descriptor<'b>) => unit = "Object.defineProperty"

  let setReadonly: ('a, string, 'b) => unit = (o, k, v) => {
    defineProperty(o, k, {writable: false, value: v})
  }
  let readonly: ('a, string) => bool = (o, k) => {
    switch getOwnPropertyDescriptor(o, k) {
    | Value(d) => d.writable === false
    | _ => false
    }
  }
}

type dyn_name = {dname: string}
type user = {mutable name: string, mutable username: string}
type address = {mutable city: string, mutable zip: int}
type person = {
  mutable name: string,
  mutable address: address,
  mutable phone: nullable<string>,
  mutable other_address: address,
  mutable passions: array<string>,
  mutable notes: TestObject.t,
}
type tester = {mutable called: bool}
type error = {mutable message: option<string>}

let apply = fn => fn()

let person = () => {
  name: "John",
  address: {
    city: "Truth",
    zip: 1234,
  },
  phone: Undefined,
  other_address: {
    city: "Beauty",
    zip: 5678,
  },
  passions: ["fruits"],
  notes: TestObject.make(),
}

type item = {
  mutable name: string,
  mutable quantity: int,
}

type items = {
  all: array<item>,
  mutable sorted: array<item>,
  mutable selected: option<item>,
}

type simple_person = {
  mutable sname: string,
  mutable susername: string,
  address: address,
}

type watchers = {
  // Tracked key in parent
  key: string,
  // Set of observers to notify on change.
  observers: Set.t<Tilia.observer>,
}

type root = {
  observer: nullable<Tilia.observer>,
  lock: bool,
}

type rec meta<'a> = {
  target: 'a,
  observed: Map.t<string, watchers>,
  proxied: 'b. Map.t<string, meta<'b>>,
  computes: 'b. Map.t<string, unit => unit>,
  proxy: 'a,
  root: root,
}

// We need this because 'Tilia.meta' is an opaque type, not exposed.
let getMeta: 'a => nullable<meta<'a>> = obj => {
  let meta = Tilia._meta(obj)
  meta
}

type people = dict<person>

type track = {mutable flush: unit => unit}
let flush = (t: track, fn) => t.flush = fn

type familiy = dict<person>

type repo = {mutable data: dict<item>}
type dateo = {date: Date.t}

type machine = Blank | Loading | Loaded

type auth = NotAuthenticated | Authenticating | Authenticated

type enter<'a> = {mutable enter: 'a => unit}

type loading = {loaded: user => unit}

type ready = {
  user: user,
  logout: unit => unit,
}
type loggedOut = {loading: unit => unit}

type state =
  | SLoading(loading)
  | SReady(ready)
  | SLoggedOut(loggedOut)
  | SBlank

type storage = {app: state}

type app = {mutable form: readonly<person>}

type obj_with_int = {
  nb1: int,
  nb2: int,
}

describe("Tilia", () => {
  it("Should observe leaf changes", () => {
    let m = {called: false}
    let p = tilia({name: "John", username: "jo"})
    let o = _observe(() => m.called = true)
    expect(p.name).toBe("John") // observe 'name'
    expect(m.called).toBe(false)
    _ready(o, true)

    // Update name with same value after ready
    p.name = "John"
    // Callback should not be called
    expect(m.called).toBe(false)

    // Update name with another value after ready
    p.name = "Mary"
    // Callback should be called
    expect(m.called).toBe(true)
    m.called = false

    // Update again
    p.name = "Three"
    // Callback should not be called
    expect(m.called).toBe(false)
  })

  it("Should observe", () => {
    open String
    let p = {name: "John", username: "jo"}
    let p = tilia(p)
    observe(
      () => {
        p.username = p.name->toLowerCase->slice(~start=0, ~end=2)
      },
    )

    expect(p.username).toBe("jo")

    // Update with same name
    p.name = "John"
    // Observing callback not called
    expect(p.username).toBe("jo")

    // Update with another name
    p.name = "Mary"
    // Observing callback called
    expect(p.username).toBe("ma")
  })

  it("Should allow mutating in observed", () => {
    let p = {name: "John", username: "jo"}
    let p = tilia(p)
    observe(
      () => {
        if !(p.name->String.endsWith("OK")) {
          p.name = p.name ++ " OK"
        }
      },
    )

    expect(p.name).toBe("John OK")

    // Update with same name
    p.name = "John OK"
    // Observing callback not called
    expect(p.name).toBe("John OK")

    // Update with another name
    p.name = "Mary"
    // Observing callback called
    expect(p.name).toBe("Mary OK")
  })

  it("Should observe mutated keys", () => {
    let p = {name: "John", username: "jo"}
    let p = tilia(p)
    observe(
      () => {
        if p.username === "john" {
          p.username = "not john"
        }
      },
    )
    p.username = "john"
    expect(p.username).toBe("not john")

    p.username = "mary"
    expect(p.username).toBe("mary")

    p.username = "john"
    expect(p.username).toBe("not john")
  })

  it("Should proxy sub-objects", () => {
    let m = {called: false}
    let p = person()
    let p = tilia(p)
    let o = _observe(() => m.called = true)
    expect(p.address.city).toBe("Truth") // observe 'address.city'
    expect(m.called).toBe(false)
    _ready(o, true)

    // Update name with same value after ready
    p.address.city = "Truth"
    // Callback should not be called
    expect(m.called).toBe(false)

    // Update name with another value after ready
    p.address.city = "Kindness"
    // Callback should be called
    expect(m.called).toBe(true)
    m.called = false

    // Update again
    p.address.city = "Sorrow"
    // Callback should not be called
    expect(m.called).toBe(false)
  })

  it("Should proxy array", () => {
    let m = {called: false}
    let p = person()
    let p = tilia(p)
    let o = _observe(() => m.called = true)
    expect(p.passions[0]).toBe(Some("fruits")) // observe key 0
    _ready(o, true)

    // Update entry
    p.passions[0] = "watercolor"
    // Callback should be called
    expect(m.called).toBe(true)
  })

  it("Should watch array index", () => {
    let m = {called: false}
    let p = person()
    let p = tilia(p)
    let o = _observe(() => m.called = true)
    expect(Array.length(p.passions)).toBe(1) // observe length
    _ready(o, true)

    // Insert new entry
    Array.push(p.passions, "watercolor")
    // Callback should be called
    expect(m.called).toBe(true)
  })

  it("Should watch object keys", () => {
    let m = {called: false}
    let p = person()
    let p = tilia(p)
    let o = _observe(() => m.called = true)
    expect(Array.length(TestObject.keys(p.notes))).toBe(0) // observe keys
    _ready(o, true)

    // Insert new entry
    TestObject.set(p.notes, "2024-12-07", "Rebuilding Tilia in ReScript")
    // Callback should be called
    expect(m.called).toBe(true)
  })

  it("Should not watch each object key", () => {
    let m = {called: false}
    let p = person()
    TestObject.set(p.notes, "day", "Seems ok")
    TestObject.set(p.notes, "night", "Seems good")
    let p = tilia(p)
    let o = _observe(() => m.called = true)
    expect(Array.length(TestObject.keys(p.notes))).toBe(2) // observe keys
    _ready(o, true)

    // Insert new entry
    TestObject.set(p.notes, "night", "Full of stars")
    // Callback should not be called
    expect(m.called).toBe(false)
  })

  it("Should not clone added objects", () => {
    let p = person()
    let a = {
      city: "Storm",
      zip: 9999,
    }
    let p = tilia(p)
    p.address = a

    expect(p.address.city).toBe("Storm")

    // Changing sub-object
    p.address.city = "Rain"

    // Changes original
    expect(a.city).toBe("Rain")
  })

  it("Should share tracking in same tree", () => {
    let m = {called: false}
    let p = person()
    let p = tilia(p)
    let o = _observe(() => m.called = true)
    expect(p.address.city).toBe("Truth") // observe 'city'
    _ready(o, true)
    expect(m.called).toBe(false)
    p.other_address = p.address
    p.other_address.city = "Love"
    // Should share the same proxy branch
    expect(p.address === p.other_address).toBe(true)

    expect(m.called).toBe(true)
  })

  it("Should not share tracking in another forest", () => {
    let m = {called: false}
    let ctx1 = make()
    let ctx2 = make()
    let p1 = ctx1.tilia(person())
    let p2 = ctx2.tilia(person())
    ctx1.observe(
      () => {
        // observe 'city'
        expect(p1.address.city).toBe(p1.address.city)
        m.called = true
      },
    )
    m.called = false
    expect(m.called).toBe(false)

    // Shares the same target, but not the same proxy
    p2.other_address = p1.address
    p2.other_address.city = "Love"
    // Should not call observer on p1
    expect(m.called).toBe(false)
    // The value changed without proxy call (target is the same).
    expect(p1.address.city).toBe("Love")
    p1.address.city = "Life"
    expect(m.called).toBe(true)
  })

  it("Should notify on key deletion", () => {
    let m = {called: false}
    let p = tilia(person())
    TestObject.set(p.notes, "hello", "Everyone")
    let o = _observe(() => m.called = true)
    expect(TestObject.get(p.notes, "hello")).toBe("Everyone") // observe "hello" key
    _ready(o, true)

    // Remove entry
    TestObject.remove(p.notes, "hello")
    // Callback should be called
    expect(m.called).toBe(true)
  })

  it("Should not proxy or watch prototype methods", () => {
    let m = {called: false}
    let p = tilia(person())
    let o = _observe(() => m.called = true)
    let x = TestObject.get(p.notes, "constructor")
    expect(x === TestObject.get(%raw(`{}`), "constructor")).toBe(true)
    _ready(o, true)

    // Edit
    TestObject.set(p.notes, "constructor", "haha")
    // Callback should be called
    expect(m.called).toBe(false)
  })

  it("Should not proxy readonly properties", () => {
    let m = {called: false}
    let p1 = person()
    let tree = %raw(`{}`)
    AnyObject.setReadonly(tree, "person", p1)
    expect(AnyObject.readonly(tree, "person")).toBe(true)
    let tree = tilia(tree)
    let o = Tilia._observe(() => m.called = true)
    let p2 = AnyObject.get(tree, "person")
    expect(p2 === p1).toBe(true)
    _ready(o, true)

    // Cannot set
    expect(AnyObject.set(tree, "person", person())).toBe(false)

    // Callback should not be called
    expect(m.called).toBe(false)

    // Exact original value is always returned
    expect(AnyObject.get(tree, "person") === p1).toBe(true)
  })

  it("Should observe undefined values", () => {
    let m = {called: false}
    let p = person()
    let p = tilia(p)
    let o = _observe(() => m.called = true)
    let phone = p.phone
    expect(phone === Undefined).toBe(true)
    _ready(o, true)

    p.phone = Value("123 456 789")
    // Callback should be called
    expect(m.called).toBe(true)
  })

  it("Should observe null values", () => {
    let m = {called: false}
    let p = person()
    let p = tilia(p)
    let o = _observe(() => m.called = true)
    let phone = p.phone
    expect(phone === Undefined).toBe(true)
    _ready(o, true)

    p.phone = Null
    expect(m.called).toBe(true)
    m.called = false

    let o2 = _observe(() => m.called = true)
    let phone2 = p.phone
    expect(phone2 === Null).toBe(true)
    _ready(o2, true)

    p.phone = Value("555")
    expect(m.called).toBe(true)
  })

  it("Should notify if update before ready", () => {
    let m = {called: false}
    let p = person()
    let p = tilia(p)
    let o = Tilia._observe(() => m.called = true)
    expect(p.name).toBe("John") // observe 'name'
    expect(m.called).toBe(false)

    // Update name before ready
    p.name = "One"
    // Callback should not be called
    expect(m.called).toBe(false)
    _ready(o, true)
    // Callback should be called during ready
    expect(m.called).toBe(true)
  })

  it("Should notify on many updates before ready", () => {
    let m = {called: false}
    let p = person()
    let p = tilia(p)
    let o = _observe(() => m.called = true)
    expect(p.name).toBe("John") // observe 'name'
    expect(m.called).toBe(false)

    _ready(o, true)
    p.name = "One"
    p.name = "Two"
    p.name = "Three"
    // Callback should be called during ready
    expect(m.called).toBe(true)
  })

  it("Should clear common key on clear", () => {
    let m1 = {called: false}
    let m2 = {called: false}
    let p = person()
    let p = tilia(p)
    let o1 = _observe(() => m1.called = true)
    expect(p.name).toBe("John") // o1 observe 'name'
    let o2 = _observe(() => m2.called = true)
    expect(p.name).toBe("John") // o2 observe 'name'
    _ready(o1, true) // o1 register, o2 not registered
    _clear(o1) // removes watchers (set empty)
    _ready(o2, true)
    expect(m2.called).toBe(false)

    // Update 'name'
    p.name = "Mary"
    // Callback should be called
    expect(m2.called).toBe(true)
  })

  // React strict mode
  it("Should support ready, clear, ready", () => {
    let m = {called: false}
    let p = person()
    let p = tilia(p)
    let o = _observe(() => m.called = true)
    expect(p.name).toBe("John") // o observe 'name'
    _ready(o, true)
    _clear(o)
    _ready(o, true)
    expect(m.called).toBe(false)

    // Update 'name'
    p.name = "Mary"
    // Callback should be called
    expect(m.called).toBe(true)
  })

  it("Should support sub-object in array", () => {
    open Option
    let m = {called: false}
    let items = tilia({
      all: [
        {name: "banana", quantity: 4},
        {name: "carrot", quantity: 8},
        {name: "apple", quantity: 2},
      ],
      // apple
      // banana
      // carrot
      sorted: [],
      selected: None,
    })
    items.sorted = computed(
      () => {
        Array.toSorted(items.all, (a, b) => String.compare(a.name, b.name))
      },
    )
    let o = _observe(() => m.called = true)
    expect(getOrThrow(items.sorted[2]).name).toBe("carrot") // o observe [2] and [2].name
    _ready(o, true)
    items.selected = items.all[1] // carrot
    expect(m.called).toBe(false)
    getOrThrow(items.selected).name = "avocado"
    expect(m.called).toBe(true)
    expect(getOrThrow(items.sorted[2]).name).toBe("banana")
    // apple
    // avocado (ex carrot)
    // banana
  })

  it("Should get internals with _meta", () => {
    let person = {
      sname: "Mary",
      susername: "mama78",
      address: {city: "Los Angleless", zip: 1234},
    }
    let p = tilia(person)
    observe(
      () => {
        p.susername = p.sname
        p.susername = p.address.city
      },
    )
    let o = _observe(_ => ())
    expect("Los Angleless").toBe(p.address.city)
    _ready(o, true)

    switch getMeta(p) {
    | Value(meta) => {
        expect(person).toBe(meta.target)
        let n = Option.getOrThrow(Map.get(meta.observed, "sname"))
        expect(1).toBe(Set.size(n.observers))

        let address = Option.getOrThrow(Map.get(meta.proxied, "address")).proxy
        expect(p.address).toBe(address)

        let meta = getMeta(address)
        switch meta {
        | Value(meta) => {
            expect(person.address).toBe(meta.target)
            let n = Option.getOrThrow(Map.get(meta.observed, "city"))
            expect(2).toBe(Set.size(n.observers))
          }
        | _ => throw("Meta is undefined")
        }
      }
    | _ => throw("Meta is undefined")
    }
  })

  it("Should clear if ready never called", () => {
    let m = {called: false}
    let p = tilia(person())
    let o = _observe(() => m.called = true)
    expect(p.name).toBe("John") // o observe 'name'

    // Ready never called
    // Observers should be zero
    switch getMeta(p) {
    | Value(meta) => {
        let n = Option.getOrThrow(Map.get(meta.observed, "name"))
        expect(0).toBe(Set.size(n.observers))
      }
    | _ => throw("Meta is undefined")
    }
    _clear(o)
  })

  it("Should delete observations on set", () => {
    let p: people = Dict.make()
    Dict.set(p, "john", person())
    let m = {called: false}
    let p = tilia(p)
    let o = _observe(() => m.called = true)
    let j = Dict.getUnsafe(p, "john")
    expect(j.name).toBe("John") // o observe 'john.name'
    _ready(o, true)

    switch getMeta(p) {
    | Value(meta) => {
        let n = Option.getOrThrow(Map.get(meta.observed, "john"))
        expect(1).toBe(Set.size(n.observers))
        Dict.set(p, "john", person())

        let n = Map.get(meta.observed, "john")
        expect(None).toBe(n)
      }
    | _ => throw("Meta is undefined")
    }
  })

  it("Should delete observations on delete", () => {
    let p: people = Dict.make()
    Dict.set(p, "john", person())
    let m = {called: false}
    let p = tilia(p)
    let o = _observe(() => m.called = true)
    let j = Dict.getUnsafe(p, "john")
    expect(j.name).toBe("John") // o observe 'john.name'
    _ready(o, true)

    switch getMeta(p) {
    | Value(meta) => {
        let n = Option.getOrThrow(Map.get(meta.observed, "john"))
        expect(1).toBe(Set.size(n.observers))
        Dict.delete(p, "john")

        let n = Map.get(meta.observed, "john")
        expect(None).toBe(n)
      }
    | _ => throw("Meta is undefined")
    }
  })

  it("Should create computed", () => {
    let p = {name: "John", username: "jo"}
    let p = tilia(p)
    let m = {called: false}
    p.name = computed(
      () => {
        m.called = true
        p.username ++ " OK"
      },
    )
    // Not called: does not have observers
    expect(m.called).toBe(false)

    p.username = "mary"
    expect(m.called).toBe(false)
    // On read, the callback is called
    expect(p.name).toBe("mary OK")
    expect(m.called).toBe(true)
  })

  it("Should set computed for recursive computed in object", () => {
    let m = {called: false}

    // To not reference self in the computed, we need first create
    // the object and then the computed.
    let p = tilia({name: "Milo", username: "milo"})
    p.name = computed(
      () => {
        m.called = true
        p.username ++ " is OK"
      },
    )

    // Not called: does not have observers
    expect(m.called).toBe(false)

    // On read, the callback is called
    expect(p.name).toBe("milo is OK")
    expect(m.called).toBe(true)
    m.called = false
    expect(p.name).toBe("milo is OK")
    expect(m.called).toBe(false)
  })

  it("Should proxify computed object", () => {
    let m = {called: false}
    let x = tilia(person())
    let p = tilia({
      name: "Louise",
      address: computed(
        () => {
          m.called = true
          {city: "Wild " ++ x.name, zip: 1234}
        },
      ),
      phone: Value("827013"),
      other_address: {city: "Angels", zip: 1234},
      passions: [],
      notes: TestObject.make(),
    })
    expect(m.called).toBe(false)
    let mo = {called: false}
    let o = _observe(() => mo.called = true)
    expect(p.address.city).toBe("Wild John")
    _ready(o, true)
    expect(m.called).toBe(true)
    m.called = false
    expect(mo.called).toBe(false)
    x.name = "Mary"
    expect(m.called).toBe(true)
    expect(mo.called).toBe(true)
  })

  it("Should not notify if unchanged computed", () => {
    let p = {name: "John", username: "jo"}
    let p = tilia(p)
    let mo = {called: false}
    observe(
      () => {
        expect(p.name).toBe(p.name) // Read p.name
        mo.called = true
      },
    )
    expect(mo.called).toBe(true)
    mo.called = false

    // Replacing a raw value with a computed with the same value should not
    // trigger a notification.
    let mc = {called: false}
    p.name = computed(
      () => {
        expect(p.username).toBe(p.username)
        mc.called = true
        p.name
      },
    )
    // Computed called (because it has observers)
    expect(mc.called).toBe(true)
    mc.called = false

    // Observer not called because value did not change
    expect(mo.called).toBe(false)

    // Compute called
    p.username = "mary"
    expect(mc.called).toBe(true)
    // Value did not change: not notified
    expect(mo.called).toBe(false)
  })

  it("Should clear compute on deleting key", () => {
    let p = {name: "John", username: "jo"}
    let p = tilia(p)
    let m = {called: false}
    p.name = computed(
      () => {
        m.called = true
        p.username ++ " OK"
      },
    )
    expect(m.called).toBe(false)
    AnyObject.deleteProperty(p, "name")

    p.username = "mary"
    expect(m.called).toBe(false)
    expect(p.name).toBe(%raw(`undefined`))
    expect(m.called).toBe(false)
  })

  it("Should clear compute on replacing compute", () => {
    let p = {name: "John", username: "jo"}
    let p = tilia(p)
    let m = {called: false}
    p.name = computed(
      () => {
        m.called = true
        p.username ++ " is nice"
      },
    )
    // Trigger first compute (and observations)
    expect(p.name).toBe("jo is nice")
    expect(m.called).toBe(true)
    m.called = false

    p.name = computed(() => p.username ++ " is beautiful")

    p.username = "Lisa"
    expect(p.name).toBe("Lisa is beautiful")
    expect(m.called).toBe(false)
  })

  it("Compute should notify cache observer on dependency change", () => {
    let p = {name: "John", username: "jo"}
    let p = tilia(p)

    // ================= mo observes p.name
    let mo = {called: false}
    observe(
      () => {
        expect(p.name).toBe(p.name)
        mo.called = true
      },
    )
    mo.called = false

    // ================= mc1 observes p.username ==> John
    let mc1 = {called: false}
    p.name = computed(
      () => {
        expect(p.username).toBe(p.username) // Just to read value from proxy
        mc1.called = true
        "John"
      },
    )
    mc1.called = false

    // On compute setup, observer is not notified (because the initial value did not change).
    // change).
    expect(mo.called).toBe(false)

    // ================= mc2 observes p.username ==> Ariana
    let mc2 = {called: false}
    p.name = computed(
      () => {
        expect(p.username).toBe(p.username) // Just to read value from proxy
        mc2.called = true
        "Ariana"
      },
    )

    // Ariana != John: observer is notified
    expect(mc2.called).toBe(true)
    expect(mo.called).toBe(true)

    mo.called = false
    mc1.called = false
    mc2.called = false

    p.username = "Mary"
    // There are observers, value computed, but did not change.
    expect(mo.called).toBe(false)
    expect(mc1.called).toBe(false)
    expect(mc2.called).toBe(true)
  })

  it("Compute should work with observers", () => {
    let p = {name: "John", username: "jo"}
    let p = tilia(p)
    p.name = computed(
      () => {
        p.username ++ " is OK"
      },
    )
    let name = ref("")
    observe(
      () => {
        name.contents = p.name
      },
    )
    expect(name.contents).toBe("jo is OK")

    p.username = "mary"
    expect(name.contents).toBe("mary is OK")
  })

  it("Computed should behave like a value", () => {
    let p = {name: "John", username: "jo"}
    let p = tilia(p)
    p.name = computed(() => p.username ++ " is OK")
    let name = ref("")
    observe(
      () => {
        name.contents = p.name
      },
    )
    expect(name.contents).toBe("jo is OK")

    p.username = "mary"
    expect(name.contents).toBe("mary is OK")
  })

  it("Should share tracking within the same forest", () => {
    let m = {called: false}
    let p1 = tilia(person())
    let p2 = tilia(person())
    let o = _observe(() => m.called = true)
    expect(p1.address.city).toBe("Truth") // observe 'city'
    _ready(o, true)
    expect(m.called).toBe(false)

    // Shares the same target, and the same proxy root
    p2.other_address = p1.address
    p2.other_address.city = "Love"
    // Should call observer on p1
    expect(m.called).toBe(true)
    // The value changed without proxy call (target is the same).
    expect(p1.address.city).toBe("Love")
    p1.address.city = "Life"
    expect(m.called).toBe(true)
  })

  it("Should share computed between trees", () => {
    let mo = {called: false}
    let src = tilia(person())
    src.name = "Nila"
    let mt = {called: false}
    let trg = tilia({
      name: computed(
        () => {
          mt.called = true
          src.name
        },
      ),
      username: "nil",
    })

    // Here it does not matter if we use p2 or p1, because it will connect
    // to the same root in any case.
    let o = _observe(() => mo.called = true)
    expect(trg.name).toBe("Nila") // observe p2.name
    expect(mt.called).toBe(true) // To get "Nila" in the computed
    mt.called = false
    _ready(o, true)

    expect(mo.called).toBe(false)

    src.name = "Alina"
    // Should call observer of p2
    expect(mo.called).toBe(true)
    // Already called because there is an observer and we notify after rebuild
    expect(mt.called).toBe(true)
    expect(trg.name).toBe("Alina")
  })

  it("Returned object from a computed should be a proxy", () => {
    let p = tilia(person())

    let m = {called: false}
    p.address = computed(
      () => {
        zip: 0,
        city: "Kernel",
      },
    )
    expect(
      () => {
        let o = _observe(() => m.called = true)
        expect(p.address.city).toBe("Kernel")
        _ready(o, true)
      },
    ).not.toThrow()
    p.address.city = "Image"
    expect(m.called).toBe(true)
  })

  it("Should not proxify class instance", () => {
    let p = tilia({date: Date.make()})
    expect(%raw(`p.date instanceof Date`)).toBe(true)
    expect(Tilia._meta(p.date)).toBe(undefined)
    expect(p.date->Date.getMilliseconds).toBe(%raw(`p.date.getMilliseconds()`))
  })

  it("Should allow state machines in observed", () => {
    let (p, setP) = signal(Blank)
    let (auth, setAuth) = signal(NotAuthenticated)
    observe(
      () => {
        switch (p.value, auth.value) {
        | (Blank, Authenticating) => setP(Loading)
        | (Loading, Authenticated) => setP(Loaded)
        | (Loaded, NotAuthenticated) => setP(Blank)
        | _ => ()
        }
      },
    )

    expect(p.value).toEqual(Blank)

    // Update dependency
    setAuth(Authenticating)
    expect(p.value).toBe(Loading)

    // Update dependency
    setAuth(Authenticated)
    expect(p.value).toBe(Loaded)

    setAuth(NotAuthenticated)
    expect(p.value).toBe(Blank)
  })

  let sleep: unit => promise<unit> = async () =>
    %raw(`new Promise(resolve => setTimeout(resolve, 10))`)

  it("should not trigger on setting the same proxied object", () => {
    let p = tilia(person())
    let m = {called: false}
    observe(
      () => {
        expect(p.address.city).toBe("Truth") // observe 'address.city'
        m.called = true
      },
    )
    m.called = false
    p.address = p.address
    expect(m.called).toBe(false)
  })

  it("should not trigger on setting the same target object", () => {
    let q = person()
    let p = tilia(q)
    let m = {called: false}
    observe(
      () => {
        expect(p.address.city).toBe("Truth") // observe 'address.city'
        m.called = true
      },
    )
    m.called = false

    // Same target object
    p.address = q.address
    expect(m.called).toBe(false)
  })

  it("should not trigger observer while in a callback", () => {
    let p = tilia(person())
    let m = {called: false}
    observe(
      () => {
        // observe 'p.address.city'
        expect(p.address.city).toBe(p.address.city)
        m.called = true
      },
    )
    m.called = false

    observe(
      () => {
        expect(m.called).toBe(false)
        p.address.city = "Beauty"
        expect(m.called).toBe(false)
      },
    )
    expect(m.called).toBe(true)
  })

  it("Should disable computed on replace", () => {
    let p1 = tilia({name: "Diana", username: "diana"})
    let p = tilia(person())
    p.name = computed(() => p1.name)
    expect("Diana").toBe(p.name)
    p.name = "Lisa"
    p1.name = "Anabel"
    // Did not update through computed
    expect("Lisa").toBe(p.name)
  })

  it("Should allow replacing computed", () => {
    let p1 = tilia({name: "Diana", username: "diana"})
    let p = tilia(person())
    p.name = computed(() => p1.name)
    expect("Diana").toBe(p.name)
    p.name = computed(() => p1.username)
    expect("diana").toBe(p.name)
    p1.name = "Anabel"
    // Did not update through old computed
    expect("diana").toBe(p.name)
  })

  // ================ EXTRA ================

  it("Should create signal", () => {
    let q = {name: "Linda", username: "linda"}
    let p2 = person()

    let (p, setP) = signal({name: "Noether", username: "emmy"})

    observe(
      () => {
        p2.name = p.value.name
      },
    )
    expect("Noether").toBe(p2.name)
    setP(q)
    expect("Linda").toBe(p2.name)
  })

  it("Should store a mutating value", () => {
    let rec ready = (set: state => unit, user) => SReady({user, logout: () => set(loggedOut(set))})
    and loggedOut = (set: state => unit) => SLoggedOut({loading: () => set(loading(set))})
    and loading = (set: state => unit) => SLoading({loaded: user => set(ready(set, user))})

    let dyn = tilia({
      app: store(loggedOut),
    })

    switch dyn.app {
    | SLoggedOut(app) => app.loading()
    | _ => throw("Not logged out")
    }

    switch dyn.app {
    | SLoading(app) => app.loaded({name: "Alice", username: "alice"})
    | _ => throw("Not loading")
    }

    switch dyn.app {
    | SReady(app) => app.logout()
    | _ => throw("Not ready")
    }

    switch dyn.app {
    | SLoggedOut(_) => ()
    | _ => throw("Not logged out")
    }
  })

  it("Should observe in store setup", () => {
    let val = ref("Dana")
    let setter = ref(s => val := s)
    let url = tilia(ref("Persephone"))

    let dyn = tilia({
      dname: store(
        set => {
          setter := set
          url.contents
        },
      ),
    })
    expect(dyn.dname).toBe("Persephone")
    setter.contents("Anibal")
    expect(dyn.dname).toBe("Anibal")
    url := "Dana"
    expect(dyn.dname).toBe("Dana")
  })

  it("Should remove computed without observers in store setup", () => {
    let val = ref("Dana")
    let setter = ref(s => val := s)

    let dyn = tilia({
      dname: store(
        set => {
          setter := set
          "Anibal"
        },
      ),
    })
    expect(dyn.dname).toBe("Anibal")
    switch getMeta(dyn) {
    | Value(meta) => {
        let n = Map.get(meta.computes, "name")
        // No observers: no computed
        expect(None).toBe(n)
      }
    | _ => throw("Meta is undefined")
    }
  })

  // This is needed to replace a computed with a regular value, from
  // inside the computed.
  it("Computed without observers should be removed", () => {
    let m = {called: false}
    let p = tilia({
      dname: computed(
        () => {
          m.called = true
          "Raphaël"
        },
      ),
    })
    expect(m.called).toBe(false)
    expect(p.dname).toBe("Raphaël")
    expect(m.called).toBe(true)
    m.called = false
    switch getMeta(p) {
    | Value(meta) => expect(Map.get(meta.computes, "dname")).toBe(None)
    | _ => throw("Meta is undefined")
    }
  })

  it("should work with computed in computed", () => {
    let m = {called: false}
    let p1 = tilia(person())
    let p2 = tilia({
      name: computed(
        () => {
          m.called = true
          p1.name ++ " p2"
        },
      ),
      username: "foo",
    })
    let p3 = tilia({
      name: computed(() => p2.name ++ " p3"),
      username: "foo",
    })
    expect(p3.name).toBe("John p2 p3")
    m.called = false
    p1.name = "Kyle"
    p1.name = "Nana"
    expect(m.called).toBe(true)
    expect(p3.name).toBe("Nana p2 p3")
  })

  it("should trigger if changed after cleared", () => {
    let m = {called: false}
    let (data, setData) = signal("Dana")
    // Observer 1 watches the data
    let o1 = _observe(() => m.called = true)
    expect(data.value).toBe("Dana")
    m.called = false

    // Observer 2 watches, and clears which clears the watchers list
    let o2 = _observe(() => ())
    expect(data.value).toBe("Dana")
    _ready(o2, true)
    _clear(o2) // Clears the watchers list

    // Change the data, but nobody is watching it because
    // the watchers list was cleared.
    setData("Lala")

    // Would see Cleared without gc
    _ready(o1, true)
    expect(m.called).toBe(true)
    expect(data.value).toBe("Lala")
  })

  it("should not trigger if unchanged after cleared", () => {
    // Using a long GC, will not trigger

    let m = {called: false}
    let (data, _) = signal("Dana")
    // Observer 1 will watch the data
    let o1 = _observe(() => m.called = true)
    expect(data.value).toBe("Dana")
    m.called = false

    // Observer 2 watches, and clears which clears the watchers list
    let o2 = _observe(() => ())
    expect(data.value).toBe("Dana")
    _ready(o2, true)
    _clear(o2) // Clears the watchers list

    // Would trigger right away without gc
    _ready(o1, true)
    // Did not trigger because the gc protected Clearing.
    expect(m.called).toBe(false)
  })

  it("should trigger with very short gc", () => {
    let ctx = make(~gc=0)
    let signal = ctx.signal
    let _observe = ctx._observe

    let m = {called: false}
    let (data, _) = signal("Dana")
    let (data2, _) = signal("Dana")
    // Observer 1 will watch the data
    let o1 = _observe(() => m.called = true)
    expect(data.value).toBe("Dana")
    m.called = false

    // Observer 2 watches, and clears which clears the watchers list
    let o2 = _observe(() => ())
    expect(data.value).toBe("Dana")
    _ready(o2, true)
    _clear(o2) // Clears the watchers list

    for _ in 1 to 2 {
      // To make the GC advance
      let o2 = _observe(() => ())
      expect(data2.value).toBe("Dana")
      _ready(o2, true)
      _clear(o2) // Clears the watchers list
    }

    // Would trigger right away without gc
    _ready(o1, true)
    // Should not trigger because the value is unchanged.
    expect(m.called).toBe(true)
  })

  it("should stop observing after _done", () => {
    let m = {called: false}
    let p = tilia(person())
    let o = _observe(() => m.called = true)
    expect(p.name).toBe("John")
    _done(o)
    expect(p.address.city).toBe("Truth")
    _ready(o, true)
    expect(m.called).toBe(false)
    p.address.city = "Irpin"
    expect(m.called).toBe(false)
    p.name = "Paulina"
    expect(m.called).toBe(true)
  })

  it("should not wrap tilia twice", () => {
    let p = tilia(person())
    expect(tilia(p)).toBe(p)
  })

  it("Should batch operations", () => {
    let m = {called: false}
    let r = make()
    let p = r.tilia(person())
    r.observe(
      () => {
        expect(p.name).toBe(p.name)
        m.called = true
      },
    )
    m.called = false

    r.batch(
      () => {
        p.name = "Dunia"
        p.name = "Maria"
        p.name = "Muholi"
        expect(m.called).toBe(false)
      },
    )
    expect(m.called).toBe(true)
  })

  it("should allow batch in batch", () => {
    let m = {called: false}
    let {batch, signal, tilia} = make()
    let (s1, setS1) = signal(0)
    let (s2, setS2) = signal(0)
    let (s3, setS3) = signal(0)
    let total = tilia({
      value: computed(
        () => {
          m.called = true
          s1.value + s2.value + s3.value
        },
      ),
    })
    expect(total.value).toBe(0)
    expect(m.called).toBe(true)
    m.called = false

    batch(
      () => {
        setS1(1)
        expect(total.value).toBe(0)
        batch(
          () => {
            setS2(2)
            expect(total.value).toBe(0)
          },
        )
        expect(total.value).toBe(0)
        setS3(5)
        expect(total.value).toBe(0)
        expect(m.called).toBe(false)
      },
    )

    expect(total.value).toBe(8)
    expect(m.called).toBe(true)
  })

  it("Should load async source", async () => {
    let m = {called: false}
    let loader = async (url, _previous, set) => {
      // needed to avoid too fast return
      await sleep()
      m.called = true
      switch url {
      | "helena" => set("Helena")
      | "bob" => set("William")
      | _ => set(url ++ " not found")
      }
    }
    let url = tilia(ref("helena"))

    let p = tilia({
      ...person(),
      name: source("", loader(url.contents, ...)),
    })
    expect(m.called).toBe(false)
    expect(p.name).toBe("")
    expect(m.called).toBe(false)

    await sleep()
    expect(m.called).toBe(true)
    m.called = false
    expect(p.name).toBe("Helena")
    url := "bob"
    // Previous value is kept until a new set is called
    expect(p.name).toBe("Helena")

    await sleep()
    expect(p.name).toBe("William")
  })

  it("should load async source with direct value if set called", async () => {
    let m = {called: false}
    let loader = async (prev, set) => {
      m.called = true
      set(prev ++ "+")
    }

    let p = tilia({
      ...person(),
      name: source("Medea", loader),
    })
    expect(p.name).toBe("Medea+")
    expect(m.called).toBe(true)
    // No observers, computed should be removed
    switch getMeta(p) {
    | Value(meta) => {
        let n = Map.get(meta.computes, "name")
        expect(None).toBe(n)
      }
    | _ => throw("Meta is undefined")
    }
  })

  it("Should load source with null initial value", async () => {
    let loader = async (_prev, set: nullable<person> => unit) => {
      await sleep()
      set(Value(person()))
    }

    let init: nullable<person> = Null
    let c = tilia({
      contents: source(init, loader),
    })
    expect(c.contents === Null).toBe(true)

    await sleep()
    switch c.contents {
    | Value(p) => expect(p.name).toBe("John")
    | _ => throw("Expected person")
    }
  })

  it("Should wrap readonly value", () => {
    let p = person()
    let app = tilia({
      form: readonly(p),
    })
    expect(app.form.data).toBe(p) // Direct equality: no proxy
    expect(
      () => {
        %raw(`app.form.data = person()`)
      },
    ).toThrow()
    expect(app.form.data).toBe(p)
  })

  it("Should use carve to derive state", () => {
    let p = carve(
      ({derived}) => {
        username: "jo",
        name: derived((p: user) => p.username ++ " is OK"),
      },
    )
    expect(p.name).toBe("jo is OK")
  })

  it("Should replace non-observing derived with computed", () => {
    let m = {called: false}
    let p = carve(
      ({derived}) => {
        username: "jo",
        name: derived(
          p => {
            m.called = true
            computed(() => p.username ++ " is OK")
          },
        ),
      },
    )
    expect(m.called).toBe(false)
    expect(p.name).toBe("jo is OK")
    expect(m.called).toBe(true)
    m.called = false
    p.username = "mary"
    expect(p.name).toBe("mary is OK")
    expect(m.called).toBe(false)
  })

  it("Should replace observing derived with computed", () => {
    let m = {called: false}
    let p = carve(
      ({derived}) => {
        username: "jo",
        name: derived(
          p => {
            m.called = true
            expect(p.username).toBe(p.username)
            computed(() => p.username ++ " is OK")
          },
        ),
      },
    )
    expect(m.called).toBe(false)
    expect(p.name).toBe("jo is OK")
    expect(m.called).toBe(true)
    m.called = false
    p.username = "mary"
    expect(p.name).toBe("mary is OK")
    expect(m.called).toBe(false)
  })

  it("Should use source for recursive derived", () => {
    let p = carve(
      ({derived}) => {
        name: "Alice",
        username: derived(
          (p: user) => {
            source(
              "lila",
              (_prev, set) => {
                switch (p.name, p.username) {
                | ("Alice", "lila") => set("Alice(lila) is OK")
                | ("Alice", "mary") => set("Alice(mary) is OK")
                | _ => set(p.name ++ " is OK")
                }
              },
            )
          },
        ),
      },
    )
    expect(p.username).toBe("Alice(lila) is OK")
    p.name = "Kevin"
    expect(p.username).toBe("Kevin is OK")
    p.name = "Bob"
  })

  it("Should derive signal", () => {
    let (a, setA) = signal(0)
    let (b, setB) = signal(0)
    let c = derived(() => a.value + b.value)
    expect(c.value).toBe(0)
    setA(1)
    expect(c.value).toBe(1)
    setB(2)
    expect(c.value).toBe(3)
  })

  it("Should watch and react to changes", () => {
    let m = {called: false}
    let (p, setP) = signal(1)
    let (q, setQ) = signal(2)
    watch(
      () => p.value,
      v => {
        m.called = true
        setQ(q.value + v)
      },
    )
    expect(q.value).toBe(2)
    expect(m.called).toBe(false)
    setQ(3)
    expect(m.called).toBe(false)
    setP(4)
    expect(m.called).toBe(true)
    expect(q.value).toBe(7)
  })

  it("Should batch changes in watch effect", () => {
    let (count, setCount) = signal(0)
    let (p, setP) = signal(1)
    let (q, setQ) = signal(2)
    watch(
      () => (p.value, q.value),
      _ => {
        setCount(count.value + 1)
      },
    )
    let (x, setX) = signal(0)
    watch(
      () => x.value,
      _ => {
        setP(p.value + 1)
        setQ(q.value + 1)
      },
    )
    expect(count.value).toBe(0)
    setX(1)
    expect(count.value).toBe(1)
    setX(2)
    expect(count.value).toBe(2)
  })

  it("Should lift signal", () => {
    let (s, setS) = signal(0)
    let obj = tilia({
      nb1: 0,
      nb2: lift(s),
    })
    expect(obj.nb2).toBe(0)
    setS(1)
    expect(obj.nb2).toBe(1)
  })

  module ErrorLog = {
    let silent: unit => unit = %raw(`function (e) {
  console.errorOrig = console.error;
  console.error = function () {};
}`)

    let reraise: 'a => 'b = %raw(`function (e) {
  throw e
}`)

    let restore: unit => unit = %raw(`function (e) {
  console.error = console.errorOrig || console.error;
  delete console.errorOrig;
}`)
  }

  it("Should not lock root on crash in computed", () => {
    ErrorLog.silent()
    try {
      let m = {called: false}
      let cm = {called: false}
      let p = tilia(person())

      observe(
        () => {
          expect(p.name).toBe(p.name)
          m.called = true
        },
      )
      m.called = false

      let (x, setX) = signal("X")
      let bad = derived(
        () =>
          switch x.value {
          | "crash" => throw("Crash machine!")
          | _ => x.value
          },
      )
      try {
        setX("crash")
        // read
        Console.log(bad.value)
        Console.log("CONTINUE")
      } catch {
      | _ => cm.called = true
      }
      expect(cm.called).toBe(true)

      let meta = getMeta(p)
      switch meta {
      | Value(meta) =>
        switch meta.root.observer {
        | Value(_) => throw("Root is locked by observer")
        | _ => ()
        }
      | _ => throw("Meta is undefined")
      }

      p.name = "Nana"
      // Observer working
      expect(m.called).toBe(true)
      ErrorLog.restore()
    } catch {
    | e =>
      ErrorLog.restore()
      ErrorLog.reraise(e)
    }
  })

  it("Should load source", () => {
    let loader = (url, previous, set) => {
      switch url.value {
      | "helena" => set(previous ++ "+Helena")
      | "bob" => set(previous ++ "+William")
      | _ => set(url.value ++ " not found")
      }
    }

    let (url, setUrl) = signal("helena")
    let p = tilia({
      ...person(),
      name: source("Medea", loader(url, ...)),
    })
    expect(p.name).toBe("Medea+Helena")
    setUrl("bob")
    expect(p.name).toBe("Medea+Helena+William")
    setUrl("helena")
    expect(p.name).toBe("Medea+Helena+William+Helena")
  })

  it("Should allow derived inside source", () => {
    let m = {called: false}
    let (x, setX) = signal("A")
    let loader = p => {
      m.called = true
      switch x.value {
      | "A" =>
        (previous, set) =>
          switch p.susername {
          | "jo" => set(previous ++ "+Jo")
          | "mary" => set(previous ++ "+Mary")
          | _ => set(p.susername ++ " not found")
          }
      | _ => (previous, set) => set(previous ++ "+B")
      }
    }
    let p = carve(
      ({derived}) => {
        susername: "jo",
        sname: source("Medea", derived(loader)),
        address: person().address,
      },
    )
    expect(m.called).toBe(false)
    expect(p.sname).toBe("Medea+Jo")
    expect(m.called).toBe(true)
    m.called = false

    p.susername = "mary"
    expect(p.sname).toBe("Medea+Jo+Mary")

    p.susername = "jo"
    expect(p.sname).toBe("Medea+Jo+Mary+Jo")
    expect(m.called).toBe(false)

    // Disable with setX
    setX("B")
    expect(m.called).toBe(true)
    expect(p.sname).toBe("Medea+Jo+Mary+Jo+B")

    m.called = false
    p.susername = "bob"
    expect(p.sname).toBe("Medea+Jo+Mary+Jo+B")
    expect(m.called).toBe(false)
  })

  it("Should allow derived inside store", () => {
    let m = {called: false}
    let (x, setX) = signal("A")
    let loader = p => {
      m.called = true
      switch x.value {
      | "A" =>
        _ =>
          switch p.susername {
          | "jo" => "Jo"
          | "mary" => "Mary"
          | _ => p.susername ++ " not found"
          }
      | _ => _ => "B"
      }
    }
    let p = carve(
      ({derived}) => {
        susername: "jo",
        sname: store(derived(loader)),
        address: person().address,
      },
    )
    expect(m.called).toBe(false)
    expect(p.sname).toBe("Jo")
    expect(m.called).toBe(true)
    m.called = false

    p.susername = "mary"
    expect(p.sname).toBe("Mary")

    p.susername = "jo"
    expect(p.sname).toBe("Jo")
    expect(m.called).toBe(false)

    // Disable with setX
    setX("B")
    expect(m.called).toBe(true)
    expect(p.sname).toBe("B")

    m.called = false
    p.susername = "bob"
    expect(p.sname).toBe("B")
    expect(m.called).toBe(false)
  })

  it("should return helpful error on computed use outside of tilia object", () => {
    let x = ref(0.)
    let s = derived(() => 4.)
    // Anti pattern ! Do not store computed value in variable.
    let c = computed(() => s.value *. 2.)
    // Zombie zone: extended glue zone.
    expect(
      () => {
        x.contents = c *. 2.
      },
    ).toThrow(
      ~message="Cannot modify or access the value of an orphan computation. See https://tiliajs.com/errors#orphan",
    )
  })

  // ================ CHANGING ================

  let none: changes<item> = {upsert: [], remove: []}
  let row = (name, quantity) => {name, quantity}

  it("Should track row updates with changing", () => {
    let table: dict<item> = Dict.make()
    let rows = tilia(table)
    Dict.set(rows, "todo-1", row("Buy milk", 1))
    Dict.set(rows, "todo-2", row("Walk dog", 1))

    let result = ref(none)
    let {changes} = changing(() => rows)
    watch(changes, e => result := e)
    expect(result.contents).toEqual(none)

    Dict.set(rows, "todo-1", row("Buy milk", 3))
    expect(result.contents).toEqual({upsert: [row("Buy milk", 3)], remove: []})

    result := none
    Dict.set(rows, "todo-2", row("Walk dog", 2))
    expect(result.contents).toEqual({upsert: [row("Walk dog", 2)], remove: []})
  })

  it("Should drain all changes in batch with changing", () => {
    let table: dict<item> = Dict.make()
    let rows = tilia(table)
    Dict.set(rows, "todo-1", row("Buy milk", 1))
    Dict.set(rows, "todo-2", row("Walk dog", 1))

    let result = ref(none)
    let {changes} = changing(() => rows)
    watch(changes, e => result := e)

    batch(
      () => {
        Dict.set(rows, "todo-1", row("Buy milk", 3))
        Dict.set(rows, "todo-2", row("Walk dog", 2))
      },
    )
    expect(result.contents).toEqual({
      upsert: [row("Buy milk", 3), row("Walk dog", 2)],
      remove: [],
    })
  })

  it("Should accumulate with guard in changing", () => {
    let table: dict<item> = Dict.make()
    let rows = tilia(table)
    Dict.set(rows, "todo-1", row("Buy milk", 1))
    Dict.set(rows, "todo-2", row("Walk dog", 1))

    let (online, setOnline) = signal(false)
    let result = ref(none)
    let {changes} = changing(() => rows, ~guard=() => online.value)
    watch(changes, e => result := e)

    Dict.set(rows, "todo-1", row("Buy milk", 3))
    Dict.set(rows, "todo-2", row("Walk dog", 2))
    expect(result.contents).toEqual(none)

    setOnline(true)
    expect(result.contents).toEqual({
      upsert: [row("Buy milk", 3), row("Walk dog", 2)],
      remove: [],
    })
  })

  it("Should not track muted writes", () => {
    let table: dict<item> = Dict.make()
    let rows = tilia(table)
    Dict.set(rows, "todo-1", row("Buy milk", 1))

    let result = ref(none)
    let {changes, mute} = changing(() => rows)
    watch(changes, e => result := e)

    Dict.set(rows, "todo-1", row("Buy milk", 3))
    expect(result.contents).toEqual({upsert: [row("Buy milk", 3)], remove: []})

    result := none
    mute(() => Dict.set(rows, "todo-2", row("Walk dog", 1)))
    expect(result.contents).toEqual(none)
  })

  it("Should preserve reactivity during mute", () => {
    let table: dict<item> = Dict.make()
    let rows = tilia(table)
    Dict.set(rows, "todo-1", row("Buy milk", 1))

    let quantity = ref(0)
    observe(
      () => {
        quantity :=
          switch Dict.get(rows, "todo-1") {
          | Some(r) => r.quantity
          | None => 0
          }
      },
    )
    expect(quantity.contents).toEqual(1)

    let {mute} = changing(() => rows)

    Dict.set(rows, "todo-1", row("Buy milk", 5))
    expect(quantity.contents).toEqual(5)

    mute(() => Dict.set(rows, "todo-1", row("Buy milk", 10)))
    expect(quantity.contents).toEqual(10)
  })

  it("Should only track non-muted writes in mixed scenario", () => {
    let table: dict<item> = Dict.make()
    let rows = tilia(table)
    Dict.set(rows, "todo-1", row("Buy milk", 1))

    let result = ref(none)
    let {changes, mute} = changing(() => rows)
    watch(changes, e => result := e)

    Dict.set(rows, "todo-1", row("Buy milk", 3))
    expect(result.contents).toEqual({upsert: [row("Buy milk", 3)], remove: []})

    result := none
    mute(() => Dict.set(rows, "todo-2", row("Walk dog", 1)))
    Dict.set(rows, "todo-1", row("Buy milk", 5))
    expect(result.contents).toEqual({upsert: [row("Buy milk", 5)], remove: []})
  })

  it("Should track deletion in remove", () => {
    let table: dict<item> = Dict.make()
    let rows = tilia(table)
    Dict.set(rows, "todo-1", row("Buy milk", 1))
    Dict.set(rows, "todo-2", row("Walk dog", 1))

    let result = ref(none)
    let {changes} = changing(() => rows)
    watch(changes, e => result := e)

    Dict.delete(rows, "todo-1")
    expect(result.contents).toEqual({upsert: [], remove: ["todo-1"]})
  })

  it("Should keep latest value on multiple writes to same key", () => {
    let table: dict<item> = Dict.make()
    let rows = tilia(table)
    Dict.set(rows, "todo-1", row("Buy milk", 1))

    let result = ref(none)
    let {changes} = changing(() => rows)
    watch(changes, e => result := e)

    batch(
      () => {
        Dict.set(rows, "todo-1", row("Buy milk", 3))
        Dict.set(rows, "todo-1", row("Buy milk", 5))
      },
    )
    expect(result.contents).toEqual({upsert: [row("Buy milk", 5)], remove: []})
  })

  it("Should re-register on data swap and keep accumulated changes", () => {
    let page1: dict<item> = Dict.make()
    Dict.set(page1, "todo-1", row("Buy milk", 1))
    Dict.set(page1, "todo-2", row("Walk dog", 1))
    let page2: dict<item> = Dict.make()
    Dict.set(page2, "todo-3", row("Clean house", 1))

    let repo = tilia({data: page1})

    let result = ref(none)
    let {changes} = changing(() => repo.data)
    watch(changes, e => result := e)

    Dict.set(repo.data, "todo-1", row("Buy milk", 3))
    expect(result.contents).toEqual({upsert: [row("Buy milk", 3)], remove: []})

    result := none
    repo.data = page2

    Dict.set(repo.data, "todo-3", row("Clean house", 2))
    expect(result.contents).toEqual({upsert: [row("Clean house", 2)], remove: []})
  })

  it("Should accumulate across data swap while offline", () => {
    let page1: dict<item> = Dict.make()
    Dict.set(page1, "todo-1", row("Buy milk", 1))
    let page2: dict<item> = Dict.make()
    Dict.set(page2, "todo-2", row("Walk dog", 1))

    let repo = tilia({data: page1})
    let (online, setOnline) = signal(false)

    let result = ref(none)
    let {changes} = changing(() => repo.data, ~guard=() => online.value)
    watch(changes, e => result := e)

    Dict.set(repo.data, "todo-1", row("Buy milk", 3))
    expect(result.contents).toEqual(none)

    repo.data = page2
    Dict.set(repo.data, "todo-2", row("Walk dog", 2))
    expect(result.contents).toEqual(none)

    setOnline(true)
    expect(result.contents).toEqual({
      upsert: [row("Buy milk", 3), row("Walk dog", 2)],
      remove: [],
    })
  })

  it("Should use sentinel object as loading state with changing", () => {
    let loading = tilia(Dict.make())

    let repo = tilia({data: loading})

    let result = ref(none)
    let {changes} = changing(() => repo.data)
    watch(changes, e => result := e)

    expect(repo.data === loading).toBe(true)
    expect(result.contents).toEqual(none)

    let page = Dict.make()
    Dict.set(page, "todo-1", row("Buy milk", 1))
    repo.data = page

    expect(repo.data === loading).toBe(false)

    Dict.set(repo.data, "todo-1", row("Buy milk", 3))
    expect(result.contents).toEqual({upsert: [row("Buy milk", 3)], remove: []})
  })
})
