Feature: Task query behavior for online, offline, sync, and invalidation

  # fully offline: reads use local store and writes are queued
  # optimistic edit: cache updates immediately
  # reconnect sync: queued writes are sent when we go back online

  Background:
    Given a task world
    And tasks are
      | id     | status | count |
      | todo-1 | active | 1     |
      | todo-2 | done   | 1     |

  Scenario: I can read tasks online and keep working offline
    Given network is "online"
    When I open "active" tasks
    And network becomes "offline"
    And I run tick for "active" tasks after 31 seconds
    Then "active" tasks should be
      | id     | status | count |
      | todo-1 | active | 1     |
    And "active" fetch calls should be 1
    And "offline" fetch calls should be 1

  Scenario: Offline edits are optimistic and queued
    Given network is "offline"
    When I open "active" tasks
    And I edit task "todo-1" to status "active" count 9
    Then task "todo-1" in cache should be status "active" count 9
    And pending sync writes should be 1
    And synced remote writes should be 0

  Scenario: Reconnect sync sends queued offline edits
    Given network is "offline"
    When I edit task "todo-1" to status "active" count 9
    And network becomes "online"
    And I sync pending writes
    Then pending sync writes should be 0
    And synced remote writes should be 1
    And remote task "todo-1" should be status "active" count 9

  Scenario: Edit that changes membership is resolved when connection returns
    Given network is "online"
    When I open "active" tasks
    And network becomes "offline"
    And I edit task "todo-1" to status "done" count 2
    And network becomes "online"
    Then no "active" tasks should remain
    And pending sync writes should be 0
    And synced remote writes should be 1

  Scenario: Active edit updates active list but not done list
    Given network is "online"
    When I open "active and done" tasks
    And I edit task "todo-1" to status "active" count 8
    And I run tick for "active and done" tasks after 0 seconds
    Then "active" fetch calls should be 2
    And "done" fetch calls should be 1

  Scenario: Live fetch channel emissions update active query
    Given network is "online"
    When I open "active" tasks
    And I emit from active fetch channel 1 with count 7
    Then "active" tasks should be
      | id     | status | count |
      | todo-1 | active | 7     |

  Scenario: Cancelled fetch channel emissions are ignored
    Given network is "online"
    When I open "active" tasks
    And I run tick for "active" tasks after 31 seconds
    And I emit from active fetch channel 1 with count 99
    Then "active" tasks should be
      | id     | status | count |
      | todo-1 | active | 1     |
