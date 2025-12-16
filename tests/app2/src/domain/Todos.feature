Feature: Todos
  Scenario: Add a todo
    Given I have no todos
    When I add a todo with id "1" and title "Test todo"
    Then I should have 1 todos

  Scenario: Toggle todo completion
    Given I have no todos
    When I add a todo with id "1" and title "Test todo"
    When I toggle todo "1"
    Then todo "1" should be completed
    And completed count should be 1
    When I toggle todo "1"
    Then todo "1" should not be completed
    And completed count should be 0

  Scenario: Remove a todo
    Given I have no todos
    When I add a todo with id "1" and title "Todo 1"
    When I add a todo with id "2" and title "Todo 2"
    Then I should have 2 todos
    When I remove todo "1"
    Then I should have 1 todos

  Scenario: Compute completed count
    Given I have no todos
    When I add a todo with id "1" and title "Todo 1"
    When I add a todo with id "2" and title "Todo 2"
    When I add a todo with id "3" and title "Todo 3"
    Then completed count should be 0
    When I toggle todo "1"
    Then completed count should be 1
    When I toggle todo "2"
    Then completed count should be 2
    When I toggle todo "1"
    Then completed count should be 1
