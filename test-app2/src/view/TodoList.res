open TiliaReact
open Todo

@genType @react.component
let make = leaf((~todos: todos) => {
  let todoList = todos.list

  <div>
    <div role="status" ariaLabel="Total Count">
      {React.string(`Total: ${todoList->Array.length->Int.toString}`)}
    </div>
    <div role="status" ariaLabel="Completed Count">
      {React.string(`Completed: ${todos.completedCount->Int.toString}`)}
    </div>
    <ul role="list" ariaLabel="Todos">
      {todoList
      ->Array.map(todo =>
        <li key={todo.id} role="listitem" ariaLabel={todo.title}>
          <span> {React.string(todo.title)} </span>
          <button
            onClick={_ => todos.toggle(todo.id)}
            ariaLabel={`${todo.completed ? "Undo" : "Complete"} ${todo.title}`}>
            {React.string(todo.completed ? "Undo" : "Complete")}
          </button>
          <button onClick={_ => todos.remove(todo.id)} ariaLabel={`Remove ${todo.title}`}>
            {React.string("Remove")}
          </button>
        </li>
      )
      ->React.array}
    </ul>
  </div>
})
