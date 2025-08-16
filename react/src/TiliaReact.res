@module("react") external useState: int => (int, (int => int) => unit) = "useState"
@module("react") external useEffect: (unit => option<unit => unit>) => unit = "useEffect"
@module("react") external useMemo: (unit => 'a, 'b) => 'a = "useMemo"
open Tilia

type tilia_react = {
  useTilia: unit => unit,
  useComputed: 'a. (unit => 'a) => 'a,
  leaf: 'a 'b. ('a => 'b) => 'a => 'b,
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
  let useComputed = fn => useMemo(() => tilia({value: computed(fn)}), []).value

  let leaf = fn => {
    p => {
      let (_, setCount) = useState(0)
      let o = _observe(() => setCount(i => i + 1))
      useEffect(() => {
        _ready(o, true)
        Some(() => _clear(o))
      })
      let node = fn(p)
      _done(o)
      node
    }
  }

  {useTilia, useComputed, leaf}
}

let tr = make(_ctx)
let useTilia = tr.useTilia
let useComputed = tr.useComputed
let leaf = tr.leaf
