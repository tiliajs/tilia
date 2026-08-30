Feature: The IndexedDB keyspace

  The store keeps rows, query records and its outbox as entries under a tag,
  and asks nothing else of persistence. This is that keyspace over IndexedDB:
  one object store, compound key [tag, key], so a tag is a range rather than
  a scan.

  Scenario: entries answer under the tag they were written to
    Given a keyspace
    When I write under "row"
      | key    | value          |
      | cat.es | {"id":"cat.es"} |
      | dog.es | {"id":"dog.es"} |
    And I write under "query"
      | key     | value |
      | spanish | ids   |
    Then reading "row" should answer
      | value           |
      | {"id":"cat.es"} |
      | {"id":"dog.es"} |
    And reading "query" should answer
      | value |
      | ids   |
    And listing "row" should answer
      | key    |
      | cat.es |
      | dog.es |

  # A tag is a range, not a filter: nothing under another tag is read to
  # answer for this one, and nothing under a tag that merely starts the same
  # way can leak into it.

  Scenario: tags stay apart, whatever the keys are
    Given a keyspace
    When I write under "row"
      | key | value |
      | z   | row-z |
    And I write under "rowdy"
      | key | value     |
      | a   | other-tag |
    Then reading "row" should answer
      | value |
      | row-z |
    And listing "rowdy" should answer
      | key |
      | a   |

  Scenario: named entries answer in the order asked for, and absent ones are skipped
    Given a keyspace
    When I write under "row"
      | key | value |
      | a   | A     |
      | b   | B     |
      | c   | C     |
    Then reading "row" for "c, a" should answer
      | value |
      | C     |
      | A     |
    And reading "row" for "a, gone, b" should answer
      | value |
      | A     |
      | B     |

  Scenario: writing nothing deletes the entry
    Given a keyspace
    When I write under "row"
      | key | value |
      | a   | A     |
      | b   | B     |
    And I delete "a" under "row"
    Then reading "row" should answer
      | value |
      | B     |
    And listing "row" should answer
      | key |
      | b   |

  # The store replays its outbox in its own constructor: it asks before
  # anything can have opened. Answering "nothing" there would lose every
  # pending write.

  Scenario: a read issued before the database is open still answers
    Given a keyspace
    When I write under "outbox"
      | key | value |
      | 1   | op    |
    And I read "outbox" without waiting for the database
    Then the read should have answered
      | value |
      | op    |

  # A fresh answer writes one entry per row, and this is the write path the
  # whole cache runs on: a transaction each would be the slowest thing the
  # application does.

  Scenario: a batch of writes is one transaction
    Given a keyspace
    When the database has opened
    And transactions are counted from now
    And I write 10 rows under "row"
    And time passes
    Then 1 transaction should have been used
    And listing "row" should have 10 keys

  # A read cannot answer without a row the store believes it has written.

  Scenario: pending writes are flushed before a read
    Given a keyspace
    When the database has opened
    Then writing "late" under "row" and reading it back at once should answer "written"

  # Persistence is command-only: the store has no way to care, so a keyspace
  # that cannot answer answers with nothing rather than hanging the caller.

  Scenario: a database that will not open answers with nothing
    Given a keyspace
    When the database cannot open
    And I write under "row"
      | key | value |
      | a   | A     |
    Then reading "row" should answer nothing
    And listing "row" should answer nothing
    And an error should have been reported

  Scenario: no IndexedDB at all answers with nothing
    Given a keyspace
    When there is no IndexedDB at all
    Then reading "row" should answer nothing
    And an error should have been reported

  Scenario: an aborted transaction drops its writes and the keyspace goes on
    Given a keyspace
    When the database has opened
    And every transaction aborts
    And I write under "row"
      | key | value |
      | a   | A     |
    And time passes
    And transactions succeed again
    Then reading "row" should answer nothing
    And an error should have been reported
