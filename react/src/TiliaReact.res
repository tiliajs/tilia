@module("react") external useState: int => (int, (int => int) => unit) = "useState"
@module("react") external useEffect: (unit => option<unit => unit>) => unit = "useEffect"
open Tilia

let makeUse = (_observe, _ready, _clear) => {
  () => {
    let (_, setCount) = useState(0)
    let o = _observe(() => setCount(i => i + 1))
    useEffect(() => {
      _ready(o, ~notifyIfChanged=true)
      Some(() => _clear(o))
    })
  }
}

let useTilia = makeUse(_observe, _ready, _clear)
