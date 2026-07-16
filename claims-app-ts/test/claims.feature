Feature: Field claims adjusting

  Adjusters triage and inspect insurance claims in the field. Work continues
  offline and syncs back to the office when connectivity returns.

  Background:
    Given a claims office with adjusters "Ana" and "Ben"
    And the claims on file are
      | id       | claimant   | peril        | city     | status   | adjuster | estimate |
      | CLM-1041 | M. Rochat  | Water damage | Lausanne | new      |          | 0        |
      | CLM-1042 | E. Baumann | Hail         | Bern     | new      |          | 0        |
      | CLM-1043 | L. Favre   | Fire         | Geneva   | assigned | Ana      | 18500    |
      | CLM-1045 | A. Conti   | Theft        | Lugano   | assigned | Ben      | 4200     |

  Scenario: Adjusters open the app on their own claims
    When "Ana" opens their claims
    And "Ben" opens their claims
    Then "Ana" sees claims "CLM-1043"
    And "Ben" sees claims "CLM-1045"

  Scenario: An adjuster takes on a new claim
    When "Ana" opens the "new" claims
    Then "Ana" sees claims "CLM-1041, CLM-1042"
    When "Ana" takes claim "CLM-1041"
    And "Ana" opens the "assigned" claims
    Then "Ana" sees claim "CLM-1041" assigned to "Ana"
    And the office shows claim "CLM-1041" assigned to "Ana"

  Scenario: An inspection recorded offline reaches the office on reconnect
    When "Ben" opens the "assigned" claims
    And "Ben" goes offline
    And "Ben" records an inspection on claim "CLM-1045" with estimate 6800 and notes "Broken window, side entrance"
    And "Ben" opens the "inspected" claims
    Then "Ben" sees claim "CLM-1045" as "inspected"
    And "Ben" has one change waiting to sync
    And the office shows claim "CLM-1045" as "assigned"
    When "Ben" comes back online
    Then "Ben" has no changes waiting to sync
    And the office shows claim "CLM-1045" as "inspected"
    And the office shows claim "CLM-1045" with estimate 6800

  Scenario: Unsynced work survives an app restart in the field
    When "Ben" opens the "assigned" claims
    And "Ben" goes offline
    And "Ben" records an inspection on claim "CLM-1045" with estimate 6800 and notes "Broken window, side entrance"
    And "Ben" restarts the app
    And "Ben" opens the "inspected" claims
    Then "Ben" sees claim "CLM-1045" as "inspected"
    And "Ben" has one change waiting to sync
    When "Ben" comes back online
    Then "Ben" has no changes waiting to sync
    And the office shows claim "CLM-1045" as "inspected"

  Scenario: Restart visibly clears one client and its adaptor calls
    When "Ana" opens the "new" claims
    And "Ana" begins restarting the app
    Then "Ana" client is reloading
    And "Ana" adaptor calls are empty
    When "Ana" finishes restarting the app
    Then "Ana" client is running
    And "Ana" sees claims "CLM-1041, CLM-1042"

  Scenario: The latest offline edit is the one that syncs
    When "Ana" opens the "all" claims
    And "Ana" goes offline
    And "Ana" changes claim "CLM-1041" field "city" to "Zurich"
    And "Ana" changes claim "CLM-1041" field "city" to "Basel"
    Then "Ana" sees claim "CLM-1041" field "city" as "Basel"
    And "Ana" has one change waiting to sync
    When "Ana" comes back online
    Then "Ana" has no changes waiting to sync
    And the office shows claim "CLM-1041" field "city" as "Basel"

  Scenario: Concurrent edits to different fields merge
    When "Ana" opens the "all" claims
    And "Ben" opens the "all" claims
    And "Ben" goes offline
    And "Ana" changes claim "CLM-1041" field "city" to "Zurich"
    And "Ben" changes claim "CLM-1041" field "notes" to "Roof inspected"
    When "Ben" comes back online
    Then "Ben" has no changes waiting to sync
    And "Ben" has no rejected changes
    And the office shows claim "CLM-1041" field "city" as "Zurich"
    And the office shows claim "CLM-1041" field "notes" as "Roof inspected"

  Scenario: Concurrent edits to the same field conflict
    When "Ana" opens the "all" claims
    And "Ben" opens the "all" claims
    And "Ben" goes offline
    And "Ana" changes claim "CLM-1041" field "city" to "Zurich"
    And "Ben" changes claim "CLM-1041" field "city" to "Basel"
    When "Ben" comes back online
    Then "Ben" has an update conflict for claim "CLM-1041"
    And "Ben" sees claim "CLM-1041" field "city" as "Zurich"
    And the office shows claim "CLM-1041" field "city" as "Zurich"
    When "Ben" begins resolving the conflict for claim "CLM-1041"
    Then "Ben" resolves field "city" with theirs "Zurich" and mine "Basel"
    When "Ben" changes the resolution field "city" to "Bern"
    And "Ben" saves the conflict resolution
    Then "Ben" has no rejected changes
    And the office shows claim "CLM-1041" field "city" as "Bern"

  Scenario: The office version wins when two adjusters take the same claim
    When "Ana" opens the "new" claims
    And "Ben" opens the "new" claims
    And "Ana" takes claim "CLM-1041"
    And "Ben" takes claim "CLM-1041"
    Then the office shows claim "CLM-1041" assigned to "Ana"
    When "Ben" opens the "assigned" claims
    Then "Ben" sees claim "CLM-1041" assigned to "Ana"

  Scenario: An estimate above the authority limit is refused
    When "Ben" opens the "assigned" claims
    And "Ben" records an inspection on claim "CLM-1045" with estimate 80000 and notes "Total loss"
    Then "Ben" is refused with "estimate above authority limit"
    And the office shows claim "CLM-1045" with estimate 4200

  Scenario: A write updates lists without asking the office
    When "Ana" opens the "new" claims
    Then the office has answered 1 read
    When "Ana" takes claim "CLM-1041"
    Then "Ana" sees claims "CLM-1042"
    And the office has answered 1 read

  Scenario: A client shows local and remote adaptor calls together
    When "Ana" opens the "new" claims
    And "Ana" takes claim "CLM-1041"
    Then "Ana" adaptor calls include
      | tag    | call  | direction | value |
      | local  | fetch | call      | some  |
      | local  | set   | reply     | some  |
      | local  | push  | call      | some  |
      | local  | set   | call      | some  |
      | local  | set   | call      | none  |
      | remote | fetch | call      | some  |
      | remote | set   | reply     | some  |
      | remote | push  | call      | some  |

  Scenario: Offline does not call the remote adaptor
    When "Ana" goes offline
    And "Ana" opens the "new" claims
    Then the office has answered 0 reads
    And "Ana" adaptor calls include
      | tag   | call  |
      | local | fetch |
    And "Ana" adaptor calls exclude
      | tag    | call  |
      | remote | fetch |

  Scenario: A live write pushes updates without any refetch
    Given the office switches to live updates
    When "Ana" opens the "new" claims
    And "Ben" opens the "new" claims
    Then the office has answered 2 reads
    And "Ana" adaptor calls include
      | tag    | call | direction | value |
      | remote | live | reply     | some  |
    When "Ana" takes claim "CLM-1041"
    Then "Ana" sees claims "CLM-1042"
    And "Ben" sees claims "CLM-1042"
    And the office has answered 2 reads

  Scenario: Lists stay sorted as claims move between them
    When "Ana" opens the "assigned" claims
    Then "Ana" sees claims in order "CLM-1043, CLM-1045"
    When "Ana" opens the "new" claims
    And "Ana" takes claim "CLM-1041"
    And "Ana" opens the "assigned" claims
    Then "Ana" sees claims in order "CLM-1041, CLM-1043, CLM-1045"
    And the office has answered 2 reads

  Scenario: Live updates reach a colleague without polling
    Given the office switches to live updates
    When "Ana" opens the "new" claims
    And "Ben" opens the "new" claims
    And "Ana" takes claim "CLM-1041"
    Then "Ben" sees claims "CLM-1042"

  Scenario: Live touch metadata keeps writer and reader distinct
    Given the office switches to live updates
    When "Ana" opens the "new" claims
    And "Ben" opens the "new" claims
    And "Ana" takes claim "CLM-1041"
    Then the office marks claim "CLM-1041" write by "Ana" and read by "Ben"

  Scenario: Live updates skip an offline adjuster until reconnect
    Given the office switches to live updates
    When "Ana" opens the "new" claims
    And "Ben" opens the "new" claims
    Then the office has 2 live subscriptions
    And "Ben" goes offline
    Then the office has 1 live subscription
    And "Ana" takes claim "CLM-1041"
    Then "Ben" sees claims "CLM-1041, CLM-1042"
    When "Ben" comes back online
    Then the office has 2 live subscriptions
    Then "Ben" sees claims "CLM-1042"

  Scenario: Polling truth refresh runs only for observed queries
    When the office advances time by 10 seconds
    Then the office has answered 0 reads
    When "Ana" opens the "new" claims
    Then the office has answered 1 read
    When the office advances time by 10 minutes
    Then the office has answered 2 reads

  Scenario: Live queries do not poll while the subscription owns freshness
    Given the office switches to live updates
    When "Ana" opens the "new" claims
    Then the office has answered 1 read
    When the office advances time by 10 minutes
    Then the office has answered 1 read

  Scenario: The fake clock can jump forward by days
    When the office advances time by 10 days
    Then fake time is 10 days after startup

  Scenario: Office network settings can be changed
    Given the office sets network latency to 150 milliseconds
    And network latency is 150 milliseconds

  Scenario: A claim removed offline disappears at the office on reconnect
    When "Ana" opens the "new" claims
    And "Ana" goes offline
    And "Ana" removes claim "CLM-1042"
    Then "Ana" no longer sees claim "CLM-1042"
    And the office still shows claim "CLM-1042"
    When "Ana" comes back online
    Then the office no longer shows claim "CLM-1042"
