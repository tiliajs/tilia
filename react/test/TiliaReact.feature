Feature: Tilia React Reactivity

  Scenario: Re-render useTilia component on changes
    Given I render the "Clouds" component
    When I click the change button
    Then I should see cloud "Blue"

  Scenario: Re-render leaf component on changes
    Given I render the "CloudLeaf" component
    When I click the change button
    Then I should see cloud "Blue"

  Scenario: Keep a letter typed just after a leaf mounts in strict mode
    Given I render the finder in strict mode
    When I open the finder and type "abc" at once
    Then the input should have shown "a, ab, abc"
