@module("react") external useState: int => (int, (int => int) => unit) = "useState"
@module("react") external useEffect: (unit => option<unit => unit>) => unit = "useEffect"
@module("react") external useMemo: (unit => 'a, 'b) => 'a = "useMemo"
open Tilia

type tilia_react = {
  useTilia: unit => unit,
  useComputed: 'a. (unit => 'a) => Tilia.signal<'a>,
}

let make = ctx => {
  let {Tilia._observe: _observe, tilia} = ctx
  let useTilia = () => {
    let (_, setCount) = useState(0)
    let o = _observe(() => setCount(i => i + 1))
    useEffect(() => {
      _ready(o, true)
      Some(() => _clear(o))
    })
  }
  let useComputed = fn => useMemo(() => tilia({ value: computed(fn) }), [])
  {useTilia, useComputed}
}

let tr = make(_ctx)
let useTilia = tr.useTilia
let useComputed = tr.useComputed
