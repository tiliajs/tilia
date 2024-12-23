@module("react") external useState: int => (int, (int => int) => unit) = "useState"
@module("react") external useEffect: (unit => option<unit => unit>) => unit = "useEffect"
open TiliaCore

let make = make
let observe = observe
let use = p => {
  Js.log("RENDER")
  let (_, setCount) = useState(0)
  let o = _connect(p, () => {
    Js.log("REDRAW")
    setCount(i => i + 1)
  })
  useEffect(() => {
    Js.log("REACT FLUSH")
    _flush(o)
    Some(() => _clear(o))
  })
  p
}
