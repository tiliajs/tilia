Feature: Tilia React Reactivity

  Scenario: Re-render useTilia component on changes
    Given I render the "Clouds" component
    When I click the change button
    Then I should see cloud "Blue"

  Scenario: Re-render leaf component on changes
    Given I render the "CloudLeaf" component
    When I click the change button
    Then I should see cloud "Blue"
