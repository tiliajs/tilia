module ClassList = {
  type t
  @send external add: (t, string) => unit = "add"
  @send external remove: (t, string) => unit = "remove"
}
@val external setTimeout: (unit => unit, int) => float = "setTimeout"
@get external classList: Dom.element => ClassList.t = "classList"

@react.component
let make = (~children: React.element) => {
  let ref = React.useRef(Nullable.null)
  React.useEffectOnEveryRender(() => {
    switch ref.current {
    | Value(dom) => {
        dom->classList->ClassList.add("bg-green-200")
        // set classname on ref
        let _ = setTimeout(() => {
          // clear classname on ref
          dom->classList->ClassList.remove("bg-green-200")
        }, 150)
      }
    | _ => ()
    }
    None
  })
  <div ref={ReactDOM.Ref.domRef(ref)} className="rounded-md"> {children} </div>
}
