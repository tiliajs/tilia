let t = Tilia.make({State.count: 0, total: 0})
open RescriptReactErrorBoundary

@react.component
let make = () => {
  let (show, setShow) = React.useState(() => true)
  let c = Tilia.use(t)

  <>
    <div className="p-6">
      <h1 className="text-3xl font-semibold m-4"> {"Tilia test"->React.string} </h1>
      <Foo/>
      <div className="p-4">
        <Button onClick={_ => setShow(s => !s)}> {(show ? "Hide" : "Show")->React.string} </Button>
      </div>
      <RescriptReactErrorBoundary fallback={(_) => <div>{"Error"->React.string}</div>}>
      {show ? <Counter t={t} /> : <div />}
      </RescriptReactErrorBoundary>
    </div>
    <div className="p-4">
      <Button onClick={_ => c.total = c.total + 1}> {c.total->Int.toString->React.string} </Button>
    </div>
  </>
}
