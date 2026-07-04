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

  Scenario: A live write pushes updates without any refetch
    Given the office switches to live updates
    When "Ana" opens the "new" claims
    And "Ben" opens the "new" claims
    Then the office has answered 2 reads
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
    Given the office sets polling truth refresh to 0.05 seconds
    When 0.08 seconds pass
    And the scheduler ticks
    Then the office has answered 0 reads
    When "Ana" opens the "new" claims
    Then the office has answered 1 read
    When 0.08 seconds pass
    And the scheduler ticks
    Then the office has answered 2 reads

  Scenario: Live truth refresh still runs for observed queries
    Given the office switches to live updates
    And the office sets live truth refresh to 0.05 seconds
    When "Ana" opens the "new" claims
    Then the office has answered 1 read
    When 0.08 seconds pass
    And the scheduler ticks
    Then the office has answered 2 reads

  Scenario: Office query settings can be changed
    Given the office sets polling truth refresh to 0.05 seconds
    And the office sets live truth refresh to 0.25 seconds
    And the office sets query expiration to 45 seconds
    And the office sets network latency to 150 milliseconds
    Then polling truth refresh is 0.05 seconds
    And live truth refresh is 0.25 seconds
    And query expiration is 45 seconds
    And network latency is 150 milliseconds

  Scenario: A claim removed offline disappears at the office on reconnect
    When "Ana" opens the "new" claims
    And "Ana" goes offline
    And "Ana" removes claim "CLM-1042"
    Then "Ana" no longer sees claim "CLM-1042"
    And the office still shows claim "CLM-1042"
    When "Ana" comes back online
    Then the office no longer shows claim "CLM-1042"
