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
    When I open the "Spanish" deck
    # Dropped from memory, but still on disk: the cache answers first.
    Then I should see "local" loaded with data
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
      | dog.es | dog     | perro       | 0    |
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

  # The local purge is I/O over the persisted query registry, so it is gated:
  # it runs on the first tick after boot, then at most every expiry.local / 8
  # (3.75 days) — in practice once per boot. All in-memory work (lastSeen,
  # refresh, memory drop) runs on every tick, unthrottled.
  Scenario: local purge does not run on every tick
    And a local cache of cards
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 0    |
    And I go "offline"
    When I open the "Spanish" deck
    And I close the deck
    And 28 days pass
    # First purge: the deck was seen 28 days ago, still retained.
    And tick is called
    And 3 days pass
    # 31 days unseen — expired, but the purge ran 3 days ago: gated.
    And tick is called
    Then local should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
    And 2 days pass
    # 5 days since the last purge: the purge runs and drops the deck.
    And tick is called
    Then local should not have "cat.es"

  # The purge is a mark and sweep. Each query record stores only its LATEST
  # ids. Mark: every id a surviving record lists. Sweep: enumerate the
  # stored rows (local.ids) and remove the unmarked ones. local.push never
  # removes rows on its own, so a card deleted on the remote lingers in
  # local storage — but only until the next purge: after a refresh no query
  # lists it anymore, even if its query is alive.
  Scenario: a card deleted on the remote is swept from local at the next purge
    When I open the "Spanish" deck
    And time passes
    Then local should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
    When the remote removes "cat.es"
    And 35 seconds pass
    And tick is called
    And time passes
    # The refresh delivered the deck without cat.es: the row is still in
    # local storage (write-through is upsert-only) but no longer listed.
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |
    And local should have
      | id     | english | translation | seen |
      | cat.es | cat     | gato        | 0    |
    And 4 days pass
    # The purge gate (expiry.local / 8) reopens: the sweep drops the row.
    And tick is called
    Then local should not have "cat.es"

  # ---- Outbox (spec-first: the engine does not implement the write path
  # yet, these scenarios fail until it lands). Rules encoded:
  # - upsert/remove while offline queue in the outbox; nothing reaches the
  #   remote until reconnect; `status.pending` counts queued ops.
  # - the outbox is durable: pending ops survive a restart and replay.
  # - an upsert joins matching open queries immediately (optimistic).
  # - a definitive remote failure moves the op to `status.rejected`;
  #   `retry` re-queues it; `discard` drops it and local state reverts to
  #   remote truth.
  # - the local purge never removes rows with a pending op. Mechanism: the
  #   purge's mark phase also marks the ids of pending outbox ops. There is
  #   no dedicated per-record query: an upsert joins the existing queries
  #   the record `matches`, and those keep the row after confirmation.
  # Batching (per-op vs per-tick remote.push) is deliberately not pinned.

  Scenario: a card updated while offline reaches the remote on reconnect
    When I open the "Spanish" deck
    And time passes
    And I go "offline"
    And I upsert
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 1    |
    Then status should have 1 pending
    # The write is queued, not sent: the remote still has the old value.
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
    # The outbox is reloaded from local storage at boot.
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
    # Optimistic: the card leaves the view before the remote confirms.
    Then I should see "remote" loaded with data
      | id     | english | translation | seen |
      | dog.es | dog     | perro       | 0    |
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

  # Papabase rejects an upsert whose version does not match the stored row.
  # The app never sends versions — the table forges one to force a
  # definitive rejection.
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
    # The op is unchanged, so the remote rejects it again.
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
    And a local cache of cards
      | id     | deck    | english | translation | seen |
      | cat.es | spanish | cat     | gato        | 0    |
    And I go "offline"
    When I open the "Spanish" deck
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