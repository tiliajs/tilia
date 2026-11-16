type element
type container = {container: element}
type screen

type renderOptions = {container: element}
@module("@testing-library/react") external render: React.element => container = "render"
@module("@testing-library/react")
external renderWithOptions: (React.element, renderOptions) => container = "render"

@module("@testing-library/react") external within: element => screen = "within"
@module("@testing-library/react")
external waitFor: (unit => promise<unit>) => promise<unit> = "waitFor"
@module("@testing-library/react") external act: (unit => promise<unit>) => promise<unit> = "act"

type roleOptions = {name?: string}
@send external getByRole: (screen, string, ~options: roleOptions=?) => element = "getByRole"
@get external textContent: element => string = "textContent"
@send
external queryByRole: (screen, string, ~options: roleOptions=?) => option<element> = "queryByRole"

type roleOptionsRe = {name: RegExp.t}
@send external getByRoleRe: (screen, string, ~options: roleOptionsRe) => element = "getByRole"

type assertion
@val external expect: 'a => assertion = "expect"
@send external toContain: (assertion, string) => unit = "toContain"
@send external toBeInTheDocument: assertion => unit = "toBeInTheDocument"
@get external not_: assertion => assertion = "not"
@send external toHaveLength: (assertion, int) => unit = "toHaveLength"
@send external toBe: (assertion, 'a) => unit = "toBe"

type user
type userEventModule
@module("@testing-library/user-event") external userEvent: userEventModule = "default"
@send external setup: userEventModule => user = "setup"
@send external click: (user, element) => promise<unit> = "click"

// Document globals
@val @scope("document") external createElement: string => element = "createElement"
@val @scope(("document", "body")) external appendChild: element => unit = "appendChild"

// Render and type outside act, as a browser does.
type root
@module("react-dom/client") external createRoot: element => root = "createRoot"
@send external renderRoot: (root, React.element) => unit = "render"
@send external unmount: root => unit = "unmount"
@send external querySelector: (element, string) => element = "querySelector"
@send external find: (element, string) => Nullable.t<element> = "querySelector"
@get external value: element => string = "value"
let setActEnvironment: bool => unit = %raw(`v => { globalThis.IS_REACT_ACT_ENVIRONMENT = v }`)
let press: element => unit = %raw(`el => el.dispatchEvent(new MouseEvent("click", { bubbles: true }))`)
let typeIn: (element, string) => unit = %raw(`function (el, text) {
  Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(el, text)
  el.dispatchEvent(new Event("input", { bubbles: true }))
}`)
let microtask: unit => promise<unit> = %raw(`() => Promise.resolve()`)
let tick: unit => promise<unit> = %raw(`() => new Promise(r => setTimeout(r, 0))`)
let wait: int => promise<unit> = %raw(`ms => new Promise(r => setTimeout(r, ms))`)
