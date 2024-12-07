type counter = {mutable count: int}

@react.component
let make = (~t: Tilia.t<State.state>) => {
  let (i, setI) = React.useState(() => 0)
  let c = Tilia.use(t)

  <div className="bg-white p-4 border-teal-600 rounded-md border">
    <Blink>
      <div className="p-4">
        <Button onClick={_ => c.count = c.count + 10}>
          {React.string(`count is ${c.count->Int.toString}`)}
        </Button>
      </div>
      <div className="p-4">
        <Button onClick={_ => setI(i => i + 1)}> {React.string(`i is ${i->Int.toString}`)} </Button>
      </div>
    </Blink>
  </div>
}
