@module("react") external useState: int => (int, (int => int) => unit) = "useState"
@module("react") external useEffect: (unit => option<unit => unit>) => unit = "useEffect"
open Tilia

let makeUseTilia = (ctx, immutable) => {
  let {_observe, _ready, _clear} = ctx
  () => {
    let (_, setCount) = useState(0)
    let o = _observe(() => setCount(i => i + 1), immutable)
    useEffect(() => {
      _ready(o, true)
      Some(() => _clear(o))
    })
  }
}

let useTilia = makeUseTilia(_ctx, false)
