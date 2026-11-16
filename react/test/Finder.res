open JsxEvent.Form
open TiliaReact

type finder = {
  mutable finding: bool,
  mutable query: string,
  sought: array<string>,
}

let tasks = ["alpha", "beta", "gamma"]

let make = () =>
  Tilia.carve(({derived}) => {
    finding: false,
    query: "",
    sought: derived(app => tasks->Array.filter(task => task->String.includes(app.query))),
  })

module Search = {
  @react.component
  let make = leaf((~app: finder) =>
    <div>
      <input value={app.query} onChange={e => app.query = target(e)["value"]} />
      <p> {app.sought->Array.length->Int.toString->React.string} </p>
    </div>
  )
}

module Page = {
  @react.component
  let make = leaf((~app: finder) =>
    <div>
      <button onClick={_ => app.finding = true}> {"Find"->React.string} </button>
      {app.finding ? <Search app /> : React.null}
    </div>
  )
}
