open Test
// Alias Todo to avoid conflict with VitestBdd.Todo
module TodoDomain = Todo
open TodoList
open VitestBdd

given("I render the TodoList component", ({step}, _) => {
  // 1. Create a detached container for strict isolation
  let host = createElement("div")
  appendChild(host)

  // 2. Create isolated domain state
  let todos = TodoDomain.make()

  // 3. Render specifically into OUR host
  let _ = renderWithOptions(<TodoList.make todos={todos} />, {container: host})

  // 4. Create a scoped 'screen'
  let screen = within(host)

  step("I add todo {string} with title {string}", async (id, title) => {
    await act(
      async () => {
        let todo = TodoDomain.makeTodo(id, title)
        todos.add(todo)
      },
    )
  })

  step("I click toggle for todo {string}", async title => {
    let user = userEvent->setup
    let re = RegExp.fromString(`(Complete|Undo) ${title}`)
    let btn = screen->getByRoleRe("button", ~options={name: re})
    await user->click(btn)
  })

  step("I click remove for todo {string}", async title => {
    let user = userEvent->setup
    let btn = screen->getByRole("button", ~options={name: `Remove ${title}`})
    await user->click(btn)
  })

  step("I should see total {string}", async expected => {
    await waitFor(
      async () => {
        Test.expect(screen->getByRole("status", ~options={name: "Total Count"}))->toHaveTextContent(
          `Total: ${expected}`,
        )
      },
    )
  })

  step("I should see completed {string}", async expected => {
    await waitFor(
      async () => {
        Test.expect(
          screen->getByRole("status", ~options={name: "Completed Count"}),
        )->toHaveTextContent(`Completed: ${expected}`)
      },
    )
  })

  step("I should see todo {string}", async title => {
    await waitFor(
      async () => {
        Test.expect(screen->getByRole("listitem", ~options={name: title}))->toBeInTheDocument
      },
    )
  })

  step("I should not see todo {string}", async title => {
    // Checking sync query result
    Test.expect(screen->queryByRole("listitem", ~options={name: title}))->not_->toBeInTheDocument
  })
})
