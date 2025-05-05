@module("react") external useState: int => (int, (int => int) => unit) = "useState"
@module("react") external useEffect: (unit => option<unit => unit>) => unit = "useEffect"
open TiliaCore

type observer = observer
let make = make
let observe = observe
let track = track
let clear = clear
let compute = compute

let use = p => {
  let (_, setCount) = useState(0)
  let o = _connect(p, () => setCount(i => i + 1))
  useEffect(() => {
    _ready(o)
    Some(() => clear(o))
  })
  p
}
