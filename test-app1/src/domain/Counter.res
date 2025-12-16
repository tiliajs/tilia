open Tilia

type counter = {
  mutable value: float,
  double: float,
  increment: unit => unit,
  decrement: unit => unit,
}

let increment = self => () => {
  self.value = self.value +. 1.0
}

let decrement = self => () => {
  self.value = self.value -. 1.0
}

let double = self => self.value *. 2.0

@genType
let make = () => {
  carve(({derived}) => {
    value: 0.0,
    double: derived(double),
    increment: derived(increment),
    decrement: derived(decrement),
  })
}

let observeCounter = (counter: counter, callback: float => unit) => {
  observe(() => {
    callback(counter.value)
  })
}
