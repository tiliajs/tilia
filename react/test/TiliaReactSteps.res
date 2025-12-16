open VitestBdd
open Test
// Import components
open Clouds
open Tilia

given("I render the {string} component", ({step}, compName) => {
  let host = createElement("div")
  appendChild(host)

  let tree: state = tilia({
    flowers: "Are nice",
    clouds: {
      morning: "can be pink",
      evening: "can be dark",
    },
  })

  let onClick = () => {
    tree.clouds.evening = "Blue"
  }

  let jsx = switch compName {
  | "Clouds" => <Clouds tree onClick />
  | "CloudLeaf" => <CloudLeaf tree onClick />
  | _ => failwith("Unknown component: " ++ compName)
  }

  let _ = renderWithOptions(jsx, {container: host})
  let screen = within(host)

  step("I click the change button", async () => {
    let user = userEvent->setup
    let btn = screen->getByRole("button")
    await user->click(btn)
  })

  step("I should see cloud {string}", async expected => {
    await waitFor(
      async () => {
        Test.expect(screen->getByRole("cloud"))->toHaveTextContent(expected)
      },
    )
  })
})
