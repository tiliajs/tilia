Feature: Task query behavior for online, offline, and replay ownership

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
    And "offline" fetch calls should be 0

  Scenario: Offline query loads from local store
    Given network is "offline"
    And local store has task "todo-1" with status "active" count 4 marked "clean"
    When I open "active" tasks
    Then "active" tasks should be
      | id     | status | count |
      | todo-1 | active | 4     |
    And "active" fetch calls should be 0
    And local fetch calls should be 1

  Scenario: Reconnect refreshes offline query from remote
    Given network is "offline"
    And local store has task "todo-1" with status "active" count 4 marked "clean"
    When I open "active" tasks
    And network becomes "online"
    Then "active" fetch calls should be 1
    And "active" tasks should be
      | id     | status | count |
      | todo-1 | active | 1     |
    And local task "todo-1" should be status "active" count 1 and "clean"

  Scenario: Offline edits are optimistic and replay on reconnect
    Given network is "offline"
    When I edit task "todo-1" to status "active" count 9
    Then task "todo-1" in cache should be status "active" count 9
    And local task "todo-1" should be status "active" count 9 and "dirty"
    And remote upsert calls should be 0
    When network becomes "online"
    Then remote upsert calls should be 1
    And synced remote writes should be 1
    And remote task "todo-1" should be status "active" count 9
    And local task "todo-1" should be status "active" count 9 and "clean"

  Scenario: Offline failure keeps write queued for next reconnect
    Given network is "offline"
    And next upsert for task "todo-1" fails offline
    When I edit task "todo-1" to status "active" count 9
    And I edit task "todo-2" to status "done" count 5
    And network becomes "online"
    Then remote upsert calls should be 2
    And synced remote writes should be 1
    When network becomes "offline"
    And network becomes "online"
    Then remote upsert calls should be 3
    And synced remote writes should be 2
    And remote task "todo-1" should be status "active" count 9
    And remote task "todo-2" should be status "done" count 5

  Scenario: Restart replays dirty rows on reconnect
    Given network is "offline"
    And local store has task "todo-1" with status "active" count 7 marked "dirty"
    And the app restarts
    When network becomes "online"
    Then remote upsert calls should be 1
    And synced remote writes should be 1
    And remote task "todo-1" should be status "active" count 7
    And local task "todo-1" should be status "active" count 7 and "clean"
    And task "todo-1" in cache should be status "active" count 7

  Scenario: Edit that changes membership is resolved on reconnect
    Given network is "online"
    When I open "active" tasks
    And network becomes "offline"
    And I edit task "todo-1" to status "done" count 2
    And network becomes "online"
    Then no "active" tasks should remain
    And remote upsert calls should be 1
    And synced remote writes should be 1

  Scenario: Fetch does not overwrite pending write
    Given network is "online"
    And remote write delivery is "paused"
    When I open "active" tasks
    And I edit task "todo-1" to status "active" count 9
    Then task "todo-1" in cache should be status "active" count 9
    And "active" fetch calls should be 2
    When I emit from held upsert channel 1 with count 9
    Then task "todo-1" in cache should be status "active" count 9
    And local task "todo-1" should be status "active" count 9 and "clean"

  Scenario: Latest same-id write owns channel callbacks
    Given network is "online"
    And remote write delivery is "paused"
    When I edit task "todo-1" to status "active" count 2
    And I edit task "todo-1" to status "active" count 3
    Then remote upsert calls should be 2
    And held upsert channels should be 2
    When I emit from held upsert channel 1 with count 99
    Then task "todo-1" in cache should be status "active" count 3
    And held upsert channels should be 1
    When I emit from held upsert channel 1 with count 3
    Then task "todo-1" in cache should be status "active" count 3
    And held upsert channels should be 0

  Scenario: Conflict response resolves and stops
    Given network is "online"
    And next upsert for task "todo-1" conflicts with status "active" count 4
    When I edit task "todo-1" to status "active" count 9
    Then remote upsert calls should be 1
    And task "todo-1" in cache should be status "active" count 4
    And remote task "todo-1" should be status "active" count 4
    And local task "todo-1" should be status "active" count 4 and "clean"

  Scenario: Rejected write does not block remaining replay
    Given network is "offline"
    And next upsert for task "todo-1" is rejected with "forbidden"
    When I edit task "todo-1" to status "active" count 9
    And I edit task "todo-2" to status "done" count 6
    And network becomes "online"
    Then remote upsert calls should be 2
    And rejected remote writes should be 1
    And remote task "todo-1" should be status "active" count 1
    And remote task "todo-2" should be status "done" count 6
    And local task "todo-1" should be status "active" count 9 and "clean"

  Scenario: Active edit updates active list but not done list
    Given network is "online"
    When I open "active and done" tasks
    And I edit task "todo-1" to status "active" count 8
    And I run tick for "active and done" tasks after 0 seconds
    Then "active" fetch calls should be 3
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

  Scenario: Same filter returns the same view
    Given network is "online"
    When I open "active" tasks
    Then the "active" tasks view should be stable
