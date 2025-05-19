open Display

let darkModeKey = "display.darkMode"

let fetchSettings = async (repo, s) => {
  switch await repo.Repo.fetchSetting(darkModeKey) {
  | Ok(darkMode) => s.darkMode = darkMode === "true"
  | _ => ()
  }
}

let make = (ctx, repo) => {
  let s = ctx.Tilia.connect({
    darkMode: false,
  })

  let t = {
    s,
    setDarkMode: async darkMode => {
      switch await repo.Repo.saveSetting(darkModeKey, darkMode ? "true" : "false") {
      | Error(_) as e => e
      | Ok(darkMode) => {
          s.darkMode = darkMode === "true"
          Ok(s.darkMode)
        }
      }
    },
  }

  ctx.observe(() => {
    switch repo.t.state {
    | Ready => ignore(fetchSettings(repo, s))
    | _ => ()
    }
  })
  t
}
