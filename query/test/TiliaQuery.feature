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
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

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
    Then I should see not local

  Scenario: go offline while a fetch is in flight
    When I open the "Spanish" deck
    Then I should see loading
    And I go "offline"
    Then I should see not local

  Scenario: a subscription updates a visible card
    When I open the "Spanish" deck
    And time passes
    And the subscription changes
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
      | dog.es | dog     | perro       | 0    |

  Scenario: a subscription adds a card to its deck
    When I open the "Spanish" deck
    And time passes
    And the subscription changes
      | id      | deck    | english | translation | seen |
      | rain.es | spanish | rain    | lluvia      | 0    |
    Then I should see "remote" loaded with data
      | id      | english | translation | seen |
      | cat.es  | cat     | gato        | 0    |
      | dog.es  | dog     | perro       | 0    |
      | rain.es | rain    | lluvia      | 0    |

  Scenario: a subscription removes a card from its deck
    When I open the "Spanish" deck
    And time passes
    And the subscription removes "cat.es"
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |

  Scenario: update a card while online
    When I open the "Spanish" deck
    And time passes
    Then I should see "remote" loaded with data
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
    And I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
      | dog.es | dog     | perro       | 0    |

  Scenario: update a card while offline
    When I open the "Spanish" deck
    And time passes
    And I go "offline"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
      | dog.es | dog     | perro       | 0    |

  Scenario: remote data becomes local after refresh timeout
    When I open the "Spanish" deck
    And time passes
    Then I should see "remote" loaded with data
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

  Scenario: an open deck is refreshed after the refresh timeout
    When I open the "Spanish" deck
    And time passes
    And the remote is updated with
      | id      | deck    | english | translation | seen |
      | rain.es | spanish | rain    | lluvia      | 0    |
    And 35 seconds pass
    And tick is called
    And time passes
    Then I should see "remote" loaded with data
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
    Then I should see "remote" loaded with data
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
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
      | dog.es | dog     | perro       | 0    |

  Scenario: a closed deck is dropped from memory after the memory timeout
    When I open the "Spanish" deck
    And time passes
    Then I should see "remote" loaded with data
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
    Then I should see "remote" loaded with data
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
    Then I should see "remote" loaded with data
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
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |
    And memory and local query "Spanish" should have ids
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
    Then I should see "remote" loaded with data
      | id      | english | translation | seen |
      | cat.es  | cat     | gato        | 0    |
      | dog.es  | dog     | perro       | 0    |
      | rain.es | rain    | lluvia      | 0    |
    And memory and local query "Spanish" should have ids
      | id      |
      | cat.es  |
      | dog.es  |
      | rain.es |

  Scenario: a rejected write lands in status.rejected
    When I open the "Spanish" deck
    And time passes
    And I upsert
      | id     | deck    | english | translation | seen | version |
      | cat.es | spanish | cat     | gato        | 9    | 5       |
    And time passes
    Then status should have 0 pending
    And status should have 1 rejected

  Scenario: retrying a rejection re-queues the op
    When I open the "Spanish" deck
    And time passes
    And I upsert
      | id     | deck    | english | translation | seen | version |
      | cat.es | spanish | cat     | gato        | 9    | 5       |
    And time passes
    And I retry the rejection for "cat.es"
    Then status should have 0 rejected
    And status should have 1 pending
    And time passes
    Then status should have 1 rejected

  Scenario: discarding a rejection reverts to remote truth
    When I open the "Spanish" deck
    And time passes
    And I upsert
      | id     | deck    | english | translation | seen | version |
      | cat.es | spanish | cat     | gato        | 9    | 5       |
    And time passes
    And I discard the rejection for "cat.es"
    Then status should have 0 rejected
    And time passes
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

  Scenario: the local purge spares rows with pending writes
    When deck "Spanish" is in local db
    And I go "offline"
    And I open the "Spanish" deck
    And I close the deck
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    And 31 days pass
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
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
    And memory and local query "Spanish" should have ids
      | id     |
      | dog.es |
    And memory and local query "Spanglish" should have ids
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

  # A failed fetch shows `Failed` at the read site and re-enters the refresh
  # loop: the next tick past the refresh window retries. A live source owns
  # its own recovery instead (a later delivery or `end`).

  Scenario: a failed fetch surfaces and retries after the refresh window
    When the remote is failing with "boom"
    And I open the "Spanish" deck
    And time passes
    Then I should see failed with "boom"
    When the remote recovers
    And 35 seconds pass
    And tick is called
    Then the remote fetch should have run 2 times
    When time passes
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

  Scenario: a failed fetch replaces a local result and retries
    When deck "Spanish" is in local db
    And the remote is failing with "boom"
    And I open the "Spanish" deck
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    When time passes
    Then I should see failed with "boom"
    When the remote recovers
    And 35 seconds pass
    And tick is called
    Then the remote fetch should have run 2 times
    When time passes
    Then I should see "remote" loaded with data
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
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    When the live source delivers
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
      | dog.es | spanish | dog     | perro       | 0    |
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
      | dog.es | dog     | perro       | 0    |
    And 35 seconds pass
    And tick is called
    And time passes
    Then the remote fetch should have run 1 time
    And I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
      | dog.es | dog     | perro       | 0    |

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
    And I should see "remote" loaded with data
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
    And memory query "Spanish" should be dropped
    When the live source delivers
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    Then memory query "Spanish" should be dropped
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
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    And the source teardown should have run 1 time

  Scenario: a live source failure recovers on the next delivery
    When the remote supports live queries
    And I open the "Spanish" deck
    And time passes
    And the live source fails with "boom"
    Then I should see failed with "boom"
    # The engine does not refetch a failed live query: recovery is the
    # source's job.
    When 35 seconds pass
    And tick is called
    Then the remote fetch should have run 1 time
    When the live source delivers
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |

  # `discard` restores server truth by refetching. On a live query this
  # tears down the subscription (its `finally` runs) and re-creates it: the
  # fresh source's first delivery replaces the discarded optimistic value.

  Scenario: discarding a rejection on a live query resubscribes for truth
    When the remote supports live queries
    And I open the "Spanish" deck
    And time passes
    And I upsert
      | id     | deck    | english | translation | seen | version |
      | cat.es | spanish | cat     | gato        | 9    | 5       |
    And time passes
    Then status should have 1 rejected
    When I discard the rejection for "cat.es"
    Then status should have 0 rejected
    And the source teardown should have run 1 time
    And the remote fetch should have run 2 times
    When time passes
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

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
    Then I should see "remote" loaded with data
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
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
      | dog.es | dog     | perro       | 0    |
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
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
    And the source teardown should have run 1 time
