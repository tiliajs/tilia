---
title: Two devices, one deck
slug: two-devices-one-deck
sort: 5
refs: [store-make, loadable-type, array, status-type]
chapter: "05"
---

Changing devices is where hand-rolled sync layers usually crack, so it is worth saying plainly: in this design, "continue on your phone" is not a feature anyone built. It is the result of two rules applied consistently: the server is authoritative, and every cache admits it is a cache.

### The meeting point

By the time Alice's train reaches the station, the laptop's outbox has drained through the gaps between tunnels. Every review she made, every card she reworded, is on the server — not because some export ran, but because that is where mutations were always headed. Closing the laptop loses nothing, because the laptop was never the owner of anything.

The phone, meanwhile, has its own store, holding whatever it saw last. At the station it gets one bar of signal and a minute of attention. The query Alice opens answers instantly from the phone's remembered copy, then its ordinary refresh returns the server's complete answer. Because fresh results are written through, the phone now carries the deck as the laptop left it:

```typescript
const result = cards.array({ deck: "spanish" }); // read through the query
const waiting = store.status.pending;            // sync through the store
```

```rescript
let result = cards.array({deck: "spanish"}) // read through the query
let waiting = store.status.pending          // sync through the store
```

No transfer occurs between the devices. The phone asks the same plain-data question the laptop asked; the shared server is where their histories meet. With the durable persistence in the next chapter, work left pending on the laptop would stay safe there, but the phone could not invent it. It would become available elsewhere only after the laptop reconnected and delivered it. That limitation is not a crack in the model; it is the model telling the truth.

Then the bus turns into the hills and the signal dies. The fresh phone answer becomes local as time passes, but its rows remain. Multi-device support, offline support, and plain cache correctness turn out to be the same discipline: one authoritative meeting point, and devices that remember without pretending to own.

Some backends push updates instead of waiting for the next refresh. That lower-level integration belongs to [Store.custom](api.html#store-custom) in the API reference; the lifecycle and the promise to the user remain the same.

::: story
Alice buys a terrible coffee, thumbs the phone awake in the bus queue, and the deck is already mid-thought: her review starts where the laptop stopped, and the card she reworded in the last tunnel reads the new way. The bus climbs; the bars vanish; the deck doesn't flinch.
:::

::: pro
Do not promise device-to-device magic. “Available on your other devices after sync” is both calmer and more accurate than suggesting that two offline devices somehow share a present.
:::

The phone now holds everything it needs. It will have to, because where the bus is going there is no third answer coming — for a week.
