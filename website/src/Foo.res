type foo = {
  mutable foo: string
}

let x = Tilia.make({
  foo: "bar"
})

@react.component
let make = () => {
  let x = Tilia.use(x)
  Js.log("Foo render")
  <div onClick={(_) => {
    x.foo = "C " ++ x.foo
  }}>{x.foo->React.string}</div>
}