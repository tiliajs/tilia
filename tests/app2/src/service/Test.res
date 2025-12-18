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
@send
external queryByRole: (screen, string, ~options: roleOptions=?) => option<element> = "queryByRole"

type roleOptionsRe = {name: RegExp.t}
@send external getByRoleRe: (screen, string, ~options: roleOptionsRe) => element = "getByRole"

type assertion
@val external expect: 'a => assertion = "expect"
@send external toHaveTextContent: (assertion, string) => unit = "toHaveTextContent"
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
