module TodoDomain = Todo
open VitestBdd

given("I have no todos", ({step}, _) => {
  let todos = TodoDomain.make()

  step("I add a todo with id {string} and title {string}", (id, title) => {
    todos.add(TodoDomain.makeTodo(id, title))
  })

  step("I toggle todo {string}", id => {
    todos.toggle(id)
  })

  step("I remove todo {string}", id => {
    todos.remove(id)
  })

  step("I should have {number} todos", count => {
    expect(todos.list->Array.length).toBe(count)
  })

  step("todo {string} should be completed", id => {
    let todo = todos.list->Array.find(t => t.id == id)
    switch todo {
    | Some(t) => expect(t.completed).toBe(true)
    | None => expect(false).toBe(true)
    }
  })

  step("completed count should be {number}", count => {
    expect(todos.completedCount).toBe(count)
  })

  step("todo {string} should not be completed", id => {
    let todo = todos.list->Array.find(t => t.id == id)
    switch todo {
    | Some(t) => expect(t.completed).toBe(false)
    | None => expect(false).toBe(true)
    }
  })
})
