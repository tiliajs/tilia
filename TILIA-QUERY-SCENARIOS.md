# Scenario batch — for review before landing

One scenario per decided rule, all in `query/test/TiliaQuery.feature`. The 41
existing scenarios stay as the split's regression proof; three of them are
rewritten because behaviour intentionally changes, and sixteen are added — one
for each new public rule, listed below. Nothing here has landed yet: each
group lands with the phase that makes it pass (`SESSION.md`).

A scenario exists here if and only if a decided rule would otherwise be
unproven, and it is phrased as behaviour. Gherkin is a translation layer, so
"internal" is not the test — "can it be said without naming the
implementation" is.

Background is the existing one — `cat.es` / `dog.es` / `cat.fr` / `dog.fr`.
"Klingon" is a deck no card belongs to.

| # | rule | lands |
| --- | --- | --- |
| 1 | `Partial` is an answer, and says so | 2a |
| 2 | an empty `Partial` is not an answer | 2a |
| 3 | a weaker answer cannot replace a stronger one while a find is open | 2a |
| 4 | an empty list is data; `one` projects it to `NoMatch`, with its claim | 2a |
| 5 | a failure replaces the result only when there is nothing to show | 2b |
| 6 | `conflict` rebases one operation and keeps it pending | 2c |
| 7 | `reject` refuses one operation; order does not imply dependency | 2c |
| 8 | `fail` rejects every operation in the push not yet answered | 2c |
| 9 | `Transient` ends the batch; an answered operation keeps its answer | 2c |
| 10 | `retry` and `discard` replace `dismiss` | 2d |
| 11 | `upsert` or `remove` clears an existing rejection | 2d |
| 12 | an unregistered query is answered from persistence, as `Partial` | 4c |
| 13 | `status.rejected` is in outbox order, whatever order replies arrive | 2d |
| 14 | a rejection holds a snapshot, not the live object | 2d |
| 15 | `lookup` may certify an answer and claim `Local` | 4c |
| 16 | no persistence is not a second mode: memory is the default | 4b |
| 17 | a store may use the binding while its own constructor is running | 3d |

Rule 5 is proved by rewriting two existing scenarios rather than by adding
one. Rules 6 and 7 share the mixed-batch scenario plus one for the merged
value, because the bug they fix is specific.

## 0 · Rename, across all 41 existing scenarios

Mechanical, lands with 2a. No scenario changes shape.

| today | becomes |
| --- | --- |
| `I should see "remote" loaded with data` | `I should see "fresh" loaded with data` |
| `I should see "local" loaded with data` | unchanged |
| — | `I should see "partial" loaded with data` |
| `I should see not local` | `I should see no data because offline` |
| `I should see failed with {string}` | `I should see no data because failed with {string}` |

## 1 · Rewritten — behaviour intentionally changes

`fetch an uncached deck while offline` gains `NoData({Offline})`. The other
two **invert**: today they assert the failure replaces the data.

```gherkin
  Scenario: fetch an uncached deck while offline
    When I go "offline"
    And I open the "Spanish" deck
    Then I should see no data because offline
    And the remote fetch should have run 0 times
    When I go "online"
    Then the remote fetch should have run 1 time
    And time passes
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

  Scenario: a failed find leaves a local result standing
    When deck "Spanish" is in local db
    And the remote is failing with "boom"
    And I open the "Spanish" deck
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    When time passes
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    And onError should have received "boom" for "Spanish"
    When the remote recovers
    And 35 seconds pass
    And tick is called
    Then the remote fetch should have run 2 times
    When time passes
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

  # Inverted. Today (`:612`) the live failure replaces the result.

  Scenario: a live source failure leaves the result standing
    When the remote supports live queries
    And I open the "Spanish" deck
    And time passes
    And the live source fails with "boom"
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    And onError should have received "boom" for "Spanish"
    # The engine still does not refetch a failed live query.
    When 35 seconds pass
    And tick is called
    Then the remote fetch should have run 1 time
    When the live source delivers
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |

  # Unchanged in substance: nothing to show, so the failure shows.
```

## 2 · Added — one per rule

New steps: `the local store answers partially`, `the local store holds
nothing`, `the local store has an index`, `the app has no persistence`, `the
remote replies out of order`, `the store replays its outbox during
construction`, `I open one card from the {string} deck`, `I should see no data
because no {string} match`, `I should see {string} loaded with no rows`,
`onError should have received {string} for {string}`, `the remote conflicts
{string} with`, `the remote rejects {string} with {string}`, `the remote stops
rejecting {string}`, `the remote is transient from {string}`, `the remote
fails the batch with {string} after {string}`, `I retry the rejection for
{string}`, `I discard the rejection for {string}`, `status rejections should
be in order`, `the query registry is empty`.

```gherkin
  Scenario: a partial result is shown
    When deck "Spanish" is in local db
    And the local store answers partially
    And I go "offline"
    And I open the "Spanish" deck
    Then I should see "partial" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

  Scenario: an empty partial waits while the remote may still answer
    When the local store holds nothing
    And I open the "Spanish" deck
    Then I should see loading
    When I go "offline"
    Then I should see no data because offline

  Scenario: a refresh does not weaken a result while it is in flight
    When deck "Spanish" is in local db
    And I open the "Spanish" deck
    And time passes
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    When 31 seconds pass
    And tick is called
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    When time passes
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

  # An empty partial is not a result: it says the store holds nothing, which
  # is not the same as the answer being empty.

  Scenario: a fresh empty result is loaded
    When I open the "Klingon" deck
    And time passes
    Then I should see "fresh" loaded with no rows
    When I open one card from the "Klingon" deck
    Then I should see no data because no "fresh" match
    When I go "offline"
    And 35 seconds pass
    And tick is called
    Then I should see no data because no "local" match

  Scenario: a conflict rebases one operation and pushes the merged value
    When I open the "Spanish" deck
    And time passes
    # The server moved on before our write left: it holds version 7 and will
    # answer this id with `conflict` once.
    And the remote conflicts "cat.es" with
      | id     | deck    | english | translation | seen | version |
      | cat.es | spanish | cat     | gato        | 0    | 7       |
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    And time passes
    # A rebase does not push itself: a server that keeps conflicting would
    # spin the outbox. The heartbeat sends it.
    Then status should have 1 pending
    When 35 seconds pass
    And tick is called
    And time passes
    Then status should have 0 pending
    # Papabase accepts an incoming version of 0 and stores `actual + 1`
    # (`MakeWorld.res:94`); the rebased write carries no version.
    And remote should have
      | id     | english | translation | seen | version |
      | cat.es | cat     | gato        | 1    | 8       |

  Scenario: a mixed batch answers each operation on its own
    When I open the "Spanish" deck
    And time passes
    And I go "offline"
    And I upsert
      | id      | deck    | english | translation | seen |
      | cat.es  | spanish | cat     | gato        | 1    |
      | dog.es  | spanish | dog     | perro       | 1    |
      | rain.es | spanish | rain    | lluvia      | 0    |
    And the remote rejects "dog.es" with "forbidden"
    And the remote conflicts "rain.es" with
      | id      | deck    | english | translation | seen | version |
      | rain.es | spanish | rain    | lluvia      | 0    | 3       |
    And I go "online"
    And time passes
    Then status should have 1 rejected
    And status should have rejection
      | kind          | id     | base | edited | message   |
      | update failed | dog.es | 0    | 1      | forbidden |
    And remote should have
      | id      | english | translation | seen |
      | cat.es  | cat     | gato        | 1    |
      | rain.es | rain    | lluvia      | 0    |

  # `fail` rejects every operation in the current push that has not yet
  # received an outcome. Earlier outcomes remain unchanged: a server that
  # acknowledged an operation and then rolled it back has to say so through
  # `receive`, not through `fail`.

  Scenario: a batch failure rejects the remaining writes
    When I open the "Spanish" deck
    And time passes
    And I go "offline"
    And I upsert
      | id      | deck    | english | translation | seen |
      | cat.es  | spanish | cat     | gato        | 1    |
      | dog.es  | spanish | dog     | perro       | 1    |
      | rain.es | spanish | rain    | lluvia      | 0    |
    And the remote fails the batch with "batch rejected" after "cat.es"
    And I go "online"
    And time passes
    Then status should have 0 pending
    And status rejections should be in order
      | id      |
      | dog.es  |
      | rain.es |
    And remote should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
      | dog.es | dog     | perro       | 0    |
    And I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |
      | cat.es | cat     | gato        | 1    |

  # `Transient` ends the batch. An operation already answered keeps its
  # answer; the rest are pushed again on a later tick.

  Scenario: a batch stops at the first transient and keeps what was answered
    When I open the "Spanish" deck
    And time passes
    And I go "offline"
    And I upsert
      | id      | deck    | english | translation | seen |
      | cat.es  | spanish | cat     | gato        | 1    |
      | dog.es  | spanish | dog     | perro       | 1    |
      | rain.es | spanish | rain    | lluvia      | 0    |
    And the remote is transient from "dog.es"
    And I go "online"
    And time passes
    Then status should have 2 pending
    And remote should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
    When the remote push recovers
    And 35 seconds pass
    And tick is called
    And time passes
    Then status should have 0 pending

  Scenario: a rejected write can be retried or discarded
    When I open the "Spanish" deck
    And time passes
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 9    |
    And the remote rejects "cat.es" with "forbidden"
    And time passes
    Then status should have rejection
      | kind          | id     | base | edited | message   |
      | update failed | cat.es | 0    | 9      | forbidden |
    And I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    When the remote rejects "dog.es" with "forbidden"
    And I upsert
      | id     | deck    | english | translation | seen |
      | dog.es | spanish | dog     | perro       | 7    |
    And time passes
    Then status should have 2 rejected
    When the remote stops rejecting "cat.es"
    And I retry the rejection for "cat.es"
    And I discard the rejection for "dog.es"
    And time passes
    Then status should have 0 rejected
    And status should have 0 pending
    And remote should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 9    |
      | dog.es | dog     | perro       | 0    |

  Scenario: writing again clears an existing rejection
    When I open the "Spanish" deck
    And time passes
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 9    |
    And the remote rejects "cat.es" with "forbidden"
    And time passes
    Then status should have 1 rejected
    When the remote stops rejecting "cat.es"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 2    |
    Then status should have 0 rejected

  Scenario: an unregistered query is answered by a scan and claims partial
    When deck "Spanish" is in local db
    And I restart the app
    And the query registry is empty
    And I go "offline"
    And I open the "Spanish" deck
    Then I should see "partial" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

  # Ordering is what an app iterates: a cascade is refused cause-first, so
  # working down the list retries the cause before the consequence.

  Scenario: rejections are listed in outbox order whatever order replies arrive
    When I open the "Spanish" deck
    And time passes
    And I go "offline"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
      | dog.es | spanish | dog     | perro       | 1    |
    And the remote rejects "dog.es" with "second"
    And the remote rejects "cat.es" with "first"
    And the remote replies out of order
    And I go "online"
    And time passes
    Then status rejections should be in order
      | id     |
      | cat.es |
      | dog.es |

  # A rejection is what was refused. The card moves on; the record does not.

  Scenario: a rejection keeps what was refused, not what happened after
    When I open the "Spanish" deck
    And time passes
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 9    |
    And the remote rejects "cat.es" with "forbidden"
    And time passes
    Then status should have rejection
      | kind          | id     | base | edited | message   |
      | update failed | cat.es | 0    | 9      | forbidden |
    When the subscription changes
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 4    |
    Then status should have rejection
      | kind          | id     | base | edited | message   |
      | update failed | cat.es | 0    | 9      | forbidden |

  Scenario: an indexed store certifies its answer and claims local
    When deck "Spanish" is in local db
    And the local store has an index
    And I restart the app
    And the query registry is empty
    And I go "offline"
    And I open the "Spanish" deck
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

  # Rule 17. The one scenario that tells the new construction apart from a
  # two-phase `connect`: this store calls `binding.place` while it is still
  # being built, so if the binding arrived afterwards the write would have
  # nowhere to land. The built-in store replays asynchronously, so the harness
  # supplies one that does not.

  Scenario: a store can use the binding during construction
    When I open the "Spanish" deck
    And time passes
    And I go "offline"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    And the store replays its outbox during construction
    And I restart the app
    And I open the "Spanish" deck
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
      | dog.es | dog     | perro       | 0    |

  Scenario: an app with no persistence still answers from memory
    When the app has no persistence
    And I open the "Spanish" deck
    And time passes
    And I go "offline"
    And 35 seconds pass
    And tick is called
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
```

## 3 · Not added

**One demand on the harness.** *The store uses the binding during its own
construction.* The built-in store's replay is asynchronous — boot calls
`local.get(~tag=outboxTag, ~set=…)` (`TiliaQuery.res:908`) — so *pending
writes survive a restart* never exercises the synchronous path. Rule 17 needs
its own scenario **and a store that replays synchronously in its
constructor**, or nothing tells the new construction apart from a two-phase
`connect`.

**`dispose` does not date the registry.** It was a rule here and is not any
more. `tick` already re-dates every observed record at most one refresh window
apart (`TiliaQuery.res:1042`), so a clean shutdown leaves a record stale by at
most 30 seconds against a 30-day local expiry. A missed stamp purges a record
up to 30 seconds early and the next find re-registers it — self-healing, and
not worth a write on the way out, an ordering rule, a flush guarantee, a
completion-aware `dispose`, or a keyspace that drops writes on close.

**Deferred — pre-existing gaps, not this refactor's.**

- Exhaustive `one` coverage. `one` has no scenario and no step today; rule 4
  gives it its first. Selecting a row from a narrowed query, and `one` over an
  empty `Partial`, stay open.
- A rejection resurfacing after a restart. Promised by the `.resi`, already in
  `TODO.md`.
- `Partial` climbing to `Fresh`, and a `Partial` result losing its last row.
  Both are restatements of rules 1 and 2.
- A fresh empty result surviving a failure, and `one` through a failure. Both
  restate rule 5.
