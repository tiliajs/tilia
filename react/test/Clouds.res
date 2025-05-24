type clouds = {
  mutable morning: string,
  mutable evening: string,
}
type state = {
  mutable flowers: string,
  mutable clouds: clouds,
}

open JsxEvent.Form
open TiliaReact

@react.component
let make = (~tree: state, ~onClick: unit => unit) => {
  useTilia()

  let onChange = e => {
    tree.clouds.evening = target(e)["value"]
  }

  <div>
    <div role="cloud">
      {"Evening clouds are "->React.string}
      {React.string(tree.clouds.evening)}
    </div>
    <button onClick={_ => onClick()}> {"Change"->React.string} </button>
    <input value={tree.clouds.evening} onChange />
  </div>
}
