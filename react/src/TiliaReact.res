@module("react") external useState: int => (int, (int => int) => unit) = "useState"
@module("react") external useEffect: (unit => option<unit => unit>) => unit = "useEffect"
open Tilia

let use = p => {
  let (_, setCount) = useState(0)
  let o = _observe(p, () => setCount(i => i + 1))
  useEffect(() => {
    _ready(o)
    Some(() => _clear(o))
  })
  p
}
