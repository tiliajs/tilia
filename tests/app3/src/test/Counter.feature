Feature: Counter Component using leaf
  Scenario: Render initial value
    Given I render the "Counter" component
    Then I should see value "0"
    And I should see double "0"

  Scenario: Increment counter
    Given I render the "Counter" component
    When I click the increment button
    Then I should see value "1"
    And I should see double "2"

  Scenario: Decrement counter
    Given I render the "Counter" component
    When I set counter to 5
    And I click the decrement button
    Then I should see value "4"
    And I should see double "8"

  Scenario: Render initial value
    Given I render the "CounterLeaf" component
    Then I should see value "0"
    And I should see double "0"

  Scenario: Increment counter
    Given I render the "CounterLeaf" component
    When I click the increment button
    Then I should see value "1"
    And I should see double "2"

  Scenario: Decrement counter
    Given I render the "CounterLeaf" component
    When I set counter to 5
    And I click the decrement button
    Then I should see value "4"
    And I should see double "8"
