Feature: display
  Scenario: Display dark mode
    Given I have a display
    Then I should see dark mode

  Scenario: Set light mode
    Given I have a display
    When I set dark mode to "light"
    Then I should see light mode