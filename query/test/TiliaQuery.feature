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
    And "active" fetch calls should be 1
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

  Scenario: Edit updates the list without any fetch
    Given network is "online"
    When I open "active" tasks
    And I edit task "todo-1" to status "active" count 8
    Then "active" tasks should be
      | id     | status | count |
      | todo-1 | active | 8     |
    And "active" fetch calls should be 1
    And local fetch calls should be 1

  Scenario: Edit that changes membership moves the task between lists without fetch
    Given network is "online"
    When I open "active and done" tasks
    And I edit task "todo-1" to status "done" count 2
    Then no "active" tasks should remain
    And "done" tasks should be
      | id     | status | count |
      | todo-1 | done   | 2     |
      | todo-2 | done   | 1     |
    And "active" fetch calls should be 1
    And "done" fetch calls should be 1

  Scenario: Lists stay sorted as membership changes
    Given network is "online"
    And tasks are
      | id     | status | count |
      | todo-1 | active | 1     |
      | todo-3 | active | 3     |
      | todo-2 | done   | 2     |
    When I open "active" tasks
    And I edit task "todo-2" to status "active" count 2
    Then "active" tasks should be
      | id     | status | count |
      | todo-1 | active | 1     |
      | todo-2 | active | 2     |
      | todo-3 | active | 3     |
    And "active" fetch calls should be 1

  Scenario: Stale refetch with unchanged rows keeps the view identity
    Given network is "online"
    When I open "active" tasks
    And I remember the "active" tasks view
    And I run tick for "active" tasks after 31 seconds
    Then "active" fetch calls should be 2
    And the "active" tasks view should be unchanged

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

  Scenario: Switching observed filter releases previous query key
    Given network is "online"
    When I observe tasks through switchable filter starting at "active"
    Then query key for "active" should be live
    And query key for "done" should be idle
    When I switch observed filter to "done"
    Then query key for "active" should be idle
    And query key for "done" should be live

  Scenario: Offline delete is optimistic and replays on reconnect
    Given network is "online"
    When I open "active" tasks
    And network becomes "offline"
    And I delete task "todo-1" with status "active" count 1
    Then task "todo-1" in cache should be absent
    And no "active" tasks should remain
    And local task "todo-1" should be a dirty tombstone with status "active" count 1
    And remote remove calls should be 0
    When network becomes "online"
    Then remote remove calls should be 1
    And remote task "todo-1" should be absent
    And local task "todo-1" should be absent

  Scenario: Restart replays a dirty delete tombstone
    Given network is "offline"
    And local store has a deleted task "todo-1" with status "active" count 1
    And the app restarts
    When network becomes "online"
    Then remote remove calls should be 1
    And remote task "todo-1" should be absent
    And local task "todo-1" should be absent

  Scenario: Delete conflict resurrects the server row
    Given network is "online"
    And next remove for task "todo-1" conflicts with status "active" count 4
    When I open "active" tasks
    And I delete task "todo-1" with status "active" count 1
    Then remote remove calls should be 1
    And task "todo-1" in cache should be status "active" count 4
    And local task "todo-1" should be status "active" count 4 and "clean"

  Scenario: Rejected delete restores the row from server
    Given network is "online"
    And next remove for task "todo-1" is rejected with "forbidden"
    When I open "active" tasks
    And I delete task "todo-1" with status "active" count 1
    Then remote remove calls should be 1
    And rejected remote writes should be 1
    And task "todo-1" in cache should be status "active" count 1
    And local task "todo-1" should be status "active" count 1 and "clean"

  Scenario: Fetch does not resurrect a pending delete
    Given network is "online"
    And remote write delivery is "paused"
    When I open "active" tasks
    And I delete task "todo-1" with status "active" count 1
    Then remote remove calls should be 1
    And no "active" tasks should remain
    And task "todo-1" in cache should be absent
    When I emit from held remove channel 1
    Then remote task "todo-1" should be absent
    And local task "todo-1" should be absent

  Scenario: Status tracks pending writes across reconnect
    Given network is "offline"
    When I edit task "todo-1" to status "active" count 9
    And I delete task "todo-2" with status "done" count 1
    Then pending writes should be 2
    When network becomes "online"
    Then pending writes should be 0

  Scenario: Rejected edit is surfaced and server truth restored
    Given network is "online"
    And next upsert for task "todo-1" is rejected with "forbidden"
    When I open "active" tasks
    And I edit task "todo-1" to status "active" count 9
    Then rejected writes on status should be 1
    And rejection 1 message should be "forbidden"
    And task "todo-1" in cache should be status "active" count 1
    And local task "todo-1" should be status "active" count 1 and "clean"
    When I dismiss rejections
    Then rejected writes on status should be 0

  Scenario: Covered fetch marks the query fresh without rows
    Given network is "online"
    And local store has task "todo-1" with status "active" count 4 marked "clean"
    And the clock advances 100 seconds
    And next fetch for "active" tasks is covered
    When I open "active" tasks
    Then "active" tasks should be
      | id     | status | count |
      | todo-1 | active | 4     |
    And "active" fetch calls should be 1
    When I run tick for "active" tasks after 10 seconds
    Then "active" fetch calls should be 1

  Scenario: Remote fetch failure is surfaced and retried when stale
    Given network is "online"
    And the clock advances 100 seconds
    And next fetch for "active" tasks fails with "boom"
    When I open "active" tasks
    Then last fetch error should be "boom"
    And "active" fetch calls should be 1
    When I run tick for "active" tasks after 10 seconds
    Then "active" fetch calls should be 2
    And last fetch error should be empty
    And "active" tasks should be
      | id     | status | count |
      | todo-1 | active | 1     |

  Scenario: Dispose stops reconnect replay
    Given network is "offline"
    When I edit task "todo-1" to status "active" count 9
    And I dispose the query state
    And network becomes "online"
    Then remote upsert calls should be 0

  Scenario: Clear empties memory and outbox for user switch
    Given network is "offline"
    When I edit task "todo-1" to status "active" count 9
    Then pending writes should be 1
    And task "todo-1" in cache should be status "active" count 9
    When I clear the query state
    Then task "todo-1" in cache should be absent
    And pending writes should be 0
    When network becomes "online"
    Then remote upsert calls should be 0

  Scenario: Detail view resolves a single row and stays reactive
    Given network is "online"
    When I open one "active" task
    Then the one "active" task should be "todo-1" with count 1
    When I edit task "todo-1" to status "active" count 7
    Then the one "active" task should be "todo-1" with count 7

  Scenario: Detail view resolves not found on empty result
    Given network is "online"
    When I open one "missing" task
    Then the one "missing" task should be not found
