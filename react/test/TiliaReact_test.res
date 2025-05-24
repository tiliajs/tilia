open Ava
open Assert

module Html = {
  type t
}

module UserEvent = {
  type t = {click: Html.t => Js.Promise.t<unit>}
}

module Testing = {
  type screen = {
    getByRole: string => Html.t,
    findByRole: string => Js.Promise.t<unit>,
  }
  // type userEvent = {setup: unit => UserEvent.t}
  type userEvent = {click: Html.t => Js.Promise.t<unit>}
  @module("@testing-library/react") external render: React.element => unit = "render"
  @module("@testing-library/react") external screen: screen = "screen"
  @module("@testing-library/user-event") external userEvent: userEvent = "default"
}

let user = Testing.userEvent //.setup()

open Testing
open Tilia
let tree = connect({
  Clouds.flowers: "Are nice",
  clouds: {
    morning: "can be pink",
    evening: "can be dark",
  },
})

asyncTest("re-render on changes", async t => {
  let onClick = () => {
    tree.clouds.evening = "Blue"
  }
  render(<Clouds tree onClick />)

  await screen.findByRole("button")

  await user.click(screen.getByRole("button"))
  await screen.findByRole("clouds")

  // ASSERT
  Js.log(screen.getByRole("clouds"))
  t->isTrue(true)
  // FIXME
  // t->is(screen.getByRole("clouds"), "Foo bar")
})
