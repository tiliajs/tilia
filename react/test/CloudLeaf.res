open Clouds
open JsxEvent.Form
open TiliaReact

@react.component
let make = leaf((~tree: state, ~onClick: unit => unit) => {
  let onChange = e => {
    tree.clouds.evening = target(e)["value"]
  }

  let isPink = useComputed(() => tree.clouds.evening === "pink")

  <div>
    <div role="cloud">
      {"Evening clouds are "->React.string}
      {React.string(tree.clouds.evening)}
    </div>
    <div role="flag"> {React.string(isPink ? "Clouds are pink" : "")} </div>
    <button onClick={_ => onClick()}> {"Change"->React.string} </button>
    <input value={tree.clouds.evening} onChange />
  </div>
})
