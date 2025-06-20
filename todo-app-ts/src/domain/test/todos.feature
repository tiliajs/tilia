Feature: Todos
  Background:
    Given I have todos
      | title            | completed |
      | Cook rice        | true      |
      | Give a hug       | false     |
      | Water the plants | false     |

  Scenario: Create a new todo
    When I create "Clean the windows"
    Then I should see "Clean the windows" in the list

  Scenario: Toggle todos
    When I toggle "Give a hug"
    Then "Give a hug" should be done
    And I toggle "Give a hug"
    Then "Give a hug" should be not done

  Scenario: Delete a todo
    And I remove "Cook rice"
    Then I should not see "Cook rice" in the list

  Scenario: Edit a todo
    When I edit "Cook rice"
    Then "Cook rice" should be selected
    * I set title to "Cook rice again"
    * I save
    Then I should see "Cook rice again" in the list
    And I should not see "Cook rice" in the list