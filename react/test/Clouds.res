type clouds = {
  mutable morning: string,
  mutable evening: string,
}
type state = {
  mutable flowers: string,
  mutable clouds: clouds,
}

open JsxEvent.Form

@react.component
let make = (~tree: state, ~onClick: unit => unit) => {
  let c = Tilia.use(tree)

  let onChange = e => {
    c.clouds.evening = target(e)["value"]
  }

  <div>
    <div role="cloud">
      {"Evening clouds are "->React.string}
      {React.string(c.clouds.evening)}
    </div>
    <button onClick={_ => onClick()}> {"Change"->React.string} </button>
    <input value={c.clouds.evening} onChange />
  </div>
}
