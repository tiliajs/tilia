Feature: Language training app

  Background:
    Given an "online" training app
    And a set of language cards on a remote
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 0    |
      | dog.es | spanish | dog     | perro       | 0    |
      | cat.fr | french  | cat     | chat        | 0    |
      | dog.fr | french  | dog     | chien       | 0    |

  Scenario: fetch a deck while online
    When I open the "Spanish" deck
    Then I should see loading
    And time passes
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

  Scenario: filter a deck by seen
    Given the remote is updated with
      | id     | deck    | english | translation | seen |
      | dog.es | spanish | dog     | perro       | 1    |
    When I open the "Spanish" deck filtered by seen "1"
    And time passes
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 1    |

  # Rule 4. An empty list is data. Only `one` projects it into "no match",
  # and the absence carries its claim because it ages like any other answer.

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

  Scenario: fetch a deck while offline
    When deck "Spanish" is in local db
    And I go "offline"
    And I open the "Spanish" deck
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

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

  Scenario: go offline while a fetch is in flight
    When I open the "Spanish" deck
    Then I should see loading
    And I go "offline"
    Then I should see no data because offline

  # Rules 1 and 2. A store without a query index holds rows without being able
  # to claim they are the whole answer. Holding nothing is not an empty
  # answer: it says so, and the engine waits or gives up.

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

  Scenario: a subscription updates a visible card
    When I open the "Spanish" deck
    And time passes
    And the subscription changes
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |
      | cat.es | cat     | gato        | 1    |

  Scenario: a subscription adds a card to its deck
    When I open the "Spanish" deck
    And time passes
    And the subscription changes
      | id      | deck    | english | translation | seen |
      | rain.es | spanish | rain    | lluvia      | 0    |
    Then I should see "fresh" loaded with data
      | id      | english | translation | seen |
      | cat.es  | cat     | gato        | 0    |
      | dog.es  | dog     | perro       | 0    |
      | rain.es | rain    | lluvia      | 0    |

  Scenario: a subscription removes a card from its deck
    When I open the "Spanish" deck
    And time passes
    And the subscription removes "cat.es"
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |

  Scenario: remote values merge with every local state
    When I open the "Spanish" deck
    And time passes
    And merge calls are cleared
    And the subscription changes
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    And I go "offline"
    And I upsert
      | id      | deck    | english | translation | seen |
      | rain.es | spanish | rain    | lluvia      | 0    |
    And the subscription changes
      | id      | deck    | english | translation | seen |
      | rain.es | spanish | rain    | lluvia      | 1    |
    And I upsert
      | id     | deck    | english | translation | seen |
      | dog.es | spanish | dog     | perro       | 1    |
    And the subscription changes
      | id     | deck    | english | translation | seen |
      | dog.es | spanish | dog     | perro       | 2    |
    And I remove "cat.es"
    And the subscription changes
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 2    |
    Then merge should have received
      | context | id      | base | edited | remote |
      | clean   | cat.es  | 0    |        | 1      |
      | created | rain.es |      | 0      | 1      |
      | updated | dog.es  | 0    | 1      | 2      |
      | removed | cat.es  | 1    |        | 2      |

  Scenario: remote truth wins when merge rejects an update
    When I open the "Spanish" deck
    And time passes
    And I go "offline"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 9    |
    And the merge rejects remote values
    And the subscription changes
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 2    |
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |
      | cat.es | cat     | gato        | 2    |
    And status should have rejection
      | kind            | id     | base | edited | message |
      | update conflict | cat.es | 0    | 9      |         |

  Scenario: update a card while online
    When I open the "Spanish" deck
    And time passes
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    And time passes
    Then remote should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
    And local should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
    And I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |
      | cat.es | cat     | gato        | 1    |

  Scenario: update a card while offline
    When I open the "Spanish" deck
    And time passes
    And I go "offline"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |
      | cat.es | cat     | gato        | 1    |

  Scenario: remote data becomes local after refresh timeout
    When I open the "Spanish" deck
    And time passes
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    And I go "offline"
    And 35 seconds pass
    And tick is called
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

  # Rule 3. A refresh asks the store again and the store answers from local
  # storage first; that must not pull a fresh result back down. Refresh opens
  # at 30s, demotion waits for the buffer until 33.75s, so this runs in the
  # window where a weaker answer would be visible.

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

  Scenario: an open deck is refreshed after the refresh timeout
    When I open the "Spanish" deck
    And time passes
    And the remote is updated with
      | id      | deck    | english | translation | seen |
      | rain.es | spanish | rain    | lluvia      | 0    |
    And 35 seconds pass
    And tick is called
    And time passes
    Then I should see "fresh" loaded with data
      | id      | english | translation | seen |
      | cat.es  | cat     | gato        | 0    |
      | dog.es  | dog     | perro       | 0    |
      | rain.es | rain    | lluvia      | 0    |

  Scenario: an open deck is not refreshed before the refresh timeout
    When I open the "Spanish" deck
    And time passes
    And the remote is updated with
      | id      | deck    | english | translation | seen |
      | rain.es | spanish | rain    | lluvia      | 0    |
    And 10 seconds pass
    And tick is called
    And time passes
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

  Scenario: a closed deck is not refreshed
    When I open the "Spanish" deck
    And time passes
    And I close the deck
    And 35 seconds pass
    And the remote is updated with
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    And tick is called
    And time passes
    Then local should have
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 0    |

  Scenario: an open deck is kept in memory after the memory timeout
    And I open the "Spanish" deck
    And time passes
    And the remote is updated with
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    And 6 minutes pass
    And tick is called
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    And time passes
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |
      | cat.es | cat     | gato        | 1    |

  Scenario: a closed deck is dropped from memory after the memory timeout
    When I open the "Spanish" deck
    And time passes
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    And I close the deck
    And 6 minutes pass
    And tick is called
    And I open the "Spanish" deck
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    And time passes
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

  Scenario: a closed deck is purged from local storage after the local timeout
    And deck "Spanish" is in local db
    And I go "offline"
    And I open the "Spanish" deck
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    And I close the deck
    And 6 minutes pass
    And tick is called
    Then local should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
    And 31 days pass
    And tick is called
    Then local should not have "cat.es"

  Scenario: local purge does not run on every tick
    And deck "Spanish" is in local db
    And I go "offline"
    And I open the "Spanish" deck
    And I close the deck
    And 28 days pass
    And tick is called
    And 3 days pass
    And tick is called
    Then local should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
    And 2 days pass
    And tick is called
    Then local should not have "cat.es"

  Scenario: a card deleted on the remote is swept from local at the next purge
    When I open the "Spanish" deck
    And time passes
    Then local should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
    And the remote removes "cat.es"
    And 35 seconds pass
    And tick is called
    And time passes
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |
    And local should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
    And 4 days pass
    And tick is called
    Then local should not have "cat.es"

  Scenario: a card updated while offline reaches the remote on reconnect
    When I open the "Spanish" deck
    And time passes
    And I go "offline"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    Then status should have 1 pending
    And remote should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
    When I go "online"
    And time passes
    Then status should have 0 pending
    And remote should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |

  # `tick` is the engine's only heartbeat: a transient push failure leaves the
  # batch pending, and nothing else is going to notice that it is time to try
  # again. An application that is online and idle must still drain its outbox.

  Scenario: a transient push failure is retried on the next tick
    When I open the "Spanish" deck
    And time passes
    And the remote push is unavailable
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    And time passes
    Then status should have 1 pending
    And the remote push should have been attempted 1 time
    When the remote push recovers
    And tick is called
    And time passes
    Then the remote push should have been attempted 2 times
    And status should have 0 pending
    And remote should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |

  # Per-operation outcomes. `conflict` hands back the server's row and keeps
  # the write pending so it rebases; `reject` refuses one write and leaves the
  # others alone, because order does not imply dependency. `fail` speaks for
  # every operation in the push that has not been answered, and `Transient`
  # ends the push without answering anything.

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
    Then status should have 1 pending
    When 35 seconds pass
    And tick is called
    And time passes
    Then status should have 0 pending
    # Papabase accepts an incoming version of 0 and stores `actual + 1`; the
    # rebased write carries no version.
    And remote should have
      | id     | english | translation | seen | version |
      | cat.es | cat     | gato        | 1    | 8       |

  Scenario: one rejected write does not affect the others
    When I open the "Spanish" deck
    And time passes
    And I go "offline"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    And I upsert
      | id     | deck    | english | translation | seen |
      | dog.es | spanish | dog     | perro       | 1    |
    And the remote rejects "cat.es" with "forbidden"
    And I go "online"
    And time passes
    Then status should have 0 pending
    And status should have rejection
      | kind          | id     | base | edited | message   |
      | update failed | cat.es | 0    | 1      | forbidden |
    And remote should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 1    |

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

  # The same order holds for a refusal the server never sent: an inbound
  # remove refuses the write it lands on, and that refusal belongs where the
  # write was queued, not where the news arrived.

  Scenario: a rejection from an inbound remove keeps its place in the order
    When I open the "Spanish" deck
    And time passes
    And I go "offline"
    And I upsert
      | id      | deck    | english | translation | seen |
      | cat.es  | spanish | cat     | gato        | 1    |
      | rain.es | spanish | rain    | lluvia      | 1    |
      | dog.es  | spanish | dog     | perro       | 1    |
    And the subscription removes "rain.es"
    And the subscription removes "dog.es"
    Then status should have 2 rejected
    When the remote rejects "cat.es" with "forbidden"
    And I go "online"
    And time passes
    Then status rejections should be in order
      | id      |
      | cat.es  |
      | rain.es |
      | dog.es  |

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

  # `retry` ends the push: the transport gave up, so every operation it did
  # not answer goes back to pending, and the next push owns them. A
  # per-operation reply that arrives after that speaks for a push that is
  # over, and must not settle a write that is queued again.

  Scenario: a reply arriving after a transient is ignored
    When I open the "Spanish" deck
    And time passes
    And I go "offline"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
      | dog.es | spanish | dog     | perro       | 1    |
    And the remote rejects "cat.es" with "forbidden"
    And the remote is transient from "dog.es"
    And the remote replies out of order
    And I go "online"
    And time passes
    Then status should have 2 pending
    And status should have 0 rejected
    When the remote push recovers
    And the remote stops rejecting "cat.es"
    And 35 seconds pass
    And tick is called
    And time passes
    Then status should have 0 pending
    And remote should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
      | dog.es | dog     | perro       | 1    |

  Scenario: pending writes survive a restart
    When I open the "Spanish" deck
    And time passes
    And I go "offline"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    And I restart the app
    Then status should have 1 pending
    When I go "online"
    And time passes
    Then status should have 0 pending
    And remote should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |

  Scenario: remove a card while online
    When I open the "Spanish" deck
    And time passes
    When I remove "cat.es"
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |
    And local query "Spanish" should have ids
      | id     |
      | dog.es |
    And time passes
    Then remote should not have "cat.es"
    And local should not have "cat.es"

  Scenario: an upserted card joins matching open queries immediately
    When I open the "Spanish" deck
    And time passes
    And I upsert
      | id      | deck    | english | translation | seen |
      | rain.es | spanish | rain    | lluvia      | 0    |
    Then I should see "fresh" loaded with data
      | id      | english | translation | seen |
      | cat.es  | cat     | gato        | 0    |
      | dog.es  | dog     | perro       | 0    |
      | rain.es | rain    | lluvia      | 0    |
    And local query "Spanish" should have ids
      | id      |
      | cat.es  |
      | dog.es  |
      | rain.es |

  Scenario: a failed write reverts to remote truth and can be discarded
    When I open the "Spanish" deck
    And time passes
    And I upsert
      | id     | deck    | english | translation | seen | version |
      | cat.es | spanish | cat     | gato        | 9    | 5       |
    And time passes
    Then status should have 0 pending
    And status should have rejection
      | kind          | id     | base | edited | message                      |
      | update failed | cat.es | 0    | 9      | version conflict on "cat.es" |
    And I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    When I discard the rejection for "cat.es"
    Then status should have 0 rejected

  Scenario: a rejected write can be retried or discarded
    When I open the "Spanish" deck
    And time passes
    And the remote rejects "cat.es" with "forbidden"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 9    |
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
    And the remote rejects "cat.es" with "forbidden"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 9    |
    And time passes
    Then status should have 1 rejected
    When the remote stops rejecting "cat.es"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 2    |
    Then status should have 0 rejected

  # A rejection is what was refused. The card moves on; the record does not.

  Scenario: a rejection keeps what was refused, not what happened after
    When I open the "Spanish" deck
    And time passes
    And the remote rejects "cat.es" with "forbidden"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 9    |
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

  # Retrying does not hand the record back: what goes into play is a copy, so
  # the row can move on again without rewriting the history the app holds.

  Scenario: a retried rejection is not the row it puts back in play
    When I open the "Spanish" deck
    And time passes
    And the remote rejects "cat.es" with "forbidden"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 9    |
    And time passes
    Then status should have 1 rejected
    When I go "offline"
    And I retry the rejection for "cat.es"
    And the subscription changes
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | CAT     | gato        | 4    |
    Then the retried rejection should still show english "cat"

  Scenario: the local purge spares rows with pending writes
    When deck "Spanish" is in local db
    And I go "offline"
    And I open the "Spanish" deck
    And I close the deck
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    And 50 days pass
    And tick is called
    Then status should have 1 pending
    And local should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |

  Scenario: moving a card updates matching queries in memory
    When deck "Spanish" is in local db
    And I open the "Spanglish" deck
    And time passes
    And I close the deck
    And I go "offline"
    When I open the "Spanish" deck
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    When I upsert
      | id     | deck      | english | translation | seen |
      | cat.es | spanglish | cat     | gato        | 1    |
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |
    When I close the deck
    And I open the "Spanglish" deck
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
    And local query "Spanish" should have ids
      | id     |
      | dog.es |
    And local query "Spanglish" should have ids
      | id     |
      | cat.es |

  Scenario: a new card joins matching queries stored locally
    When deck "Spanish" is in local db
    And I upsert
      | id      | deck    | english | translation | seen |
      | rain.es | spanish | rain    | lluvia      | 0    |
    And time passes
    Then status should have 0 pending
    When tick is called
    Then local query "Spanish" should have ids
      | id      |
      | cat.es  |
      | dog.es  |
      | rain.es |

  # A failure replaces the result only when there is no data to show.
  # Otherwise the current result stays visible and the message goes to
  # `onError`: some data beats an error in place of a list, and a list
  # blinking data to error to data is worse than either.
  #
  # Either way the query re-enters the refresh loop and the next tick past the
  # refresh window retries. A live source owns its own recovery instead (a
  # later delivery or `end`).

  Scenario: a failed find with nothing to show surfaces and retries
    When the remote is failing with "boom"
    And I open the "Spanish" deck
    And time passes
    Then I should see no data because failed with "boom"
    And onError should have received nothing
    When the remote recovers
    And 35 seconds pass
    And tick is called
    Then the remote fetch should have run 2 times
    When time passes
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

  # Live queries: the adaptor answers through `channel.live` and keeps the
  # result fresh itself. It registers its teardown with `channel.finally`
  # and calls `channel.end` when its source shuts down. The engine owns
  # late-callback suppression: anything a closed fetch says is ignored.

  Scenario: a live delivery updates the result without periodic refresh
    When the remote supports live queries
    And I open the "Spanish" deck
    And time passes
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    When the live source delivers
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
      | dog.es | spanish | dog     | perro       | 0    |
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |
      | cat.es | cat     | gato        | 1    |
    And 35 seconds pass
    And tick is called
    And time passes
    Then the remote fetch should have run 1 time
    And I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |
      | cat.es | cat     | gato        | 1    |

  Scenario: a live source that ends re-enters periodic refresh
    When the remote supports live queries
    And I open the "Spanish" deck
    And time passes
    When the live source ends
    Then the source teardown should have run 1 time
    When the remote is updated with
      | id      | deck    | english | translation | seen |
      | rain.es | spanish | rain    | lluvia      | 0    |
    And 35 seconds pass
    And tick is called
    And time passes
    Then the remote fetch should have run 2 times
    And I should see "fresh" loaded with data
      | id      | english | translation | seen |
      | cat.es  | cat     | gato        | 0    |
      | dog.es  | dog     | perro       | 0    |
      | rain.es | rain    | lluvia      | 0    |

  Scenario: an unobserved live query keeps its source until memory eviction
    When the remote supports live queries
    And I open the "Spanish" deck
    And time passes
    And I close the deck
    And 3 minutes pass
    And tick is called
    Then the source teardown should have run 0 times
    When 3 minutes pass
    And tick is called
    Then the source teardown should have run 1 time
    And query "Spanish" should be dropped from memory
    When the live source delivers
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    Then query "Spanish" should be dropped from memory
    And the source teardown should have run 1 time

  Scenario: deliveries from an ended source are ignored
    When the remote supports live queries
    And I open the "Spanish" deck
    And time passes
    And the live source ends
    Then the source teardown should have run 1 time
    When the live source delivers
      | id      | deck    | english | translation | seen |
      | rain.es | spanish | rain    | lluvia      | 0    |
    And the live source fails with "boom"
    And the live source ends
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    And the source teardown should have run 1 time

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
    # The engine does not refetch a failed live query: recovery is the
    # source's job.
    When 35 seconds pass
    And tick is called
    Then the remote fetch should have run 1 time
    When the live source delivers
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |

  Scenario: a late reply from a superseded fetch is ignored
    When I open the "Spanish" deck
    And time passes
    And 35 seconds pass
    And tick is called
    Then the remote fetch should have run 2 times
    When the superseded fetch delivers
      | id      | deck    | english | translation | seen |
      | rain.es | spanish | rain    | lluvia      | 0    |
    And the superseded fetch fails with "boom"
    # Assert before the network flush: the replacement response must not be
    # able to repair a result a late callback corrupted.
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    When time passes
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

  Scenario: going offline does not end a live query
    When the remote supports live queries
    And I open the "Spanish" deck
    And time passes
    And I go "offline"
    When the live source delivers
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
      | dog.es | spanish | dog     | perro       | 0    |
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |
      | cat.es | cat     | gato        | 1    |
    And the source teardown should have run 0 times

  Scenario: a teardown registered after a synchronous end runs immediately
    When the live source ends during fetch
    And I open the "Spanish" deck
    Then the source teardown should have run 1 time

  Scenario: dispose tears down live sources and is safe to call twice
    When the remote supports live queries
    And I open the "Spanish" deck
    And time passes
    When I dispose the app
    And I dispose the app
    Then the source teardown should have run 1 time
    # A disposed fetch is closed: anything the source still says is ignored.
    When the live source delivers
      | id      | deck    | english | translation | seen |
      | rain.es | spanish | rain    | lluvia      | 0    |
    And the live source fails with "boom"
    And the live source ends
    Then I should see "fresh" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    And the source teardown should have run 1 time
