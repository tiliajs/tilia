Feature: Counter
  Scenario: Initialize with zero
    Given counter is initialized
    Then counter value should be 0
    And counter double should be 0

  Scenario: Increment counter
    Given counter is initialized
    When I increment the counter
    Then counter value should be 1

  Scenario: Decrement counter
    Given counter is initialized
    When I set counter to 5
    When I decrement the counter
    Then counter value should be 4

  Scenario: Compute double
    Given counter is initialized
    When I set counter to 5
    Then counter double should be 10

  Scenario: Notify observers on change
    Given counter is initialized
    Then counter should notify observers on change
