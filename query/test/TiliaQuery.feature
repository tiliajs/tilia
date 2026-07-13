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
