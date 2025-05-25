# A todo app

This application is a simple demo built with
[Tilia](https://github.com/tiliajs/tilia/blob/main/README.md).

**install and run**

In the root of the monorepo, run:

Install dependencies:

```sh
pnpm i
```

Build all packages:

```sh
pnpm build
```

Start the app:

```sh
pnpm todo-ts dev
```

Then open http://localhost:5173/ in your browser.

## Documentation

Some interesting files to look at:

- [app.ts](./src/domain/feature/app.ts): The app is a state machine.
- [todos.ts](./src/domain/feature/todos/todos.ts): The todos feature.
- [App.tsx](./src/App.tsx): The main app component (React) as a single file for simplicity.
