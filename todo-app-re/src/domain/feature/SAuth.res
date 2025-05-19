open Auth

let make = ctx => {
  let s = ctx.Tilia.connect({
    auth: NotAuthenticated,
  })

  {
    s,
    login: user => s.auth = Authenticated(user),
    logout: () => s.auth = NotAuthenticated,
  }
}
