Feature: TodoList Component
  Scenario: Render empty list
    Given I render the TodoList component
    Then I should see total "0"
    And I should see completed "0"

  Scenario: Render todos
    Given I render the TodoList component
    When I add todo "1" with title "Todo 1"
    And I add todo "2" with title "Todo 2"
    Then I should see total "2"
    And I should see todo "Todo 1"
    And I should see todo "Todo 2"

  Scenario: Toggle todo completion
    Given I render the TodoList component
    When I add todo "1" with title "Todo 1"
    And I click toggle for todo "Todo 1"
    Then I should see completed "1"

  Scenario: Remove todo
    Given I render the TodoList component
    When I add todo "1" with title "Todo 1"
    And I add todo "2" with title "Todo 2"
    Then I should see total "2"
    When I click remove for todo "Todo 1"
    Then I should see total "1"
    And I should not see todo "Todo 1"
