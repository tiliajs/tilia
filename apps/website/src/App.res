let t = Tilia.make({State.count: 0, total: 0})

@react.component
let make = () => {
  let (show, setShow) = React.useState(() => true)
  let c = Tilia.use(t)

  <Blink>
    <div className="p-6">
      <h1 className="text-3xl font-semibold m-4"> {"Tilia test"->React.string} </h1>
      <div className="p-4">
        <Button onClick={_ => setShow(s => !s)}> {(show ? "Hide" : "Show")->React.string} </Button>
      </div>
      {show ? <Counter t={t} /> : <div />}
    </div>
    <div className="p-4">
      <Button onClick={_ => c.total = c.total + 1}> {c.total->Int.toString->React.string} </Button>
    </div>
  </Blink>
}
