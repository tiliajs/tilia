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
    And a local cache of cards
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 0    |
      | cat.fr | french  | cat     | chat        | 0    |
    And I go "offline"
    When I open the "Spanish" deck
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |

  Scenario: fetch an uncached deck while offline
    And I go "offline"
    When I open the "Spanish" deck
    Then I should see not local

  Scenario: go offline while a fetch is in flight
    When I open the "Spanish" deck
    Then I should see loading
    And I go "offline"
    Then I should see not local

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
    And I open the "Spanish" deck
    And time passes
    And I go "offline"
    When I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    # Not sure what we should see here. I guess that it should switch to 'local'
    # after refresh timeout if not refreshed from remote.
    # TODO: switch flag during refresh timeout.
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 1    |
      | dog.es | dog     | perro       | 0    |

  Scenario: remote data becomes local after refresh timeout
    And I open the "Spanish" deck
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

  # Default expiry: refresh 30 seconds, memory 5 minutes, local 30 days.

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

  # Remote loads are written through to local storage (upsert-only: rows
  # deleted on the remote linger in local until the local purge).
  Scenario: a closed deck is not refreshed
    When I open the "Spanish" deck
    And time passes
    And I close the deck
    And 35 seconds pass
    # Not visible for refresh duration = stop refreshing.
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
    When I open the "Spanish" deck
    Then I should see loading
    And time passes
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |

  # Dropping from memory (memory timeout) and purging local storage (local
  # timeout) are distinct: after 6 minutes the cards are gone from memory but
  # still on disk, only after 30 days do they leave local storage.
  Scenario: a closed deck is purged from local storage after the local timeout
    And a local cache of cards
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 0    |
    And I go "offline"
    When I open the "Spanish" deck
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
    And I close the deck
    And 6 minutes pass
    And tick is called
    Then local should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
    And 31 days pass
    And tick is called
    Then local should not have "cat.es"