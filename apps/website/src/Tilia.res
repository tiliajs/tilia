open TiliaCore
type t<'a> = TiliaCore.t<'a>
let make = TiliaCore.make

let _inc = i => i + 1
let use = (t: t<'a>) => {
  let (_, setCount) = React.useState(() => 0)
  let o = _connect(t, () => setCount(_inc))
  let (_, p) = t
  React.useEffectOnEveryRender(() => {
    _flush(o)
    Some(() => _clear(o))
  })
  p
}
