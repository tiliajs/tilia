## The core idea {.api}

<a id="frp"></a>

<section class="doc frp">

### Start from one practical problem

UI code gets fragile when domain logic lives in components. You can ship quickly, but testing, refactoring, and cross-platform reuse become expensive.

Tilia works best when each feature is isolated behind `carve`, with `derived` used as glue around explicit helper functions.

### Initial carve example (service-injected)

```typescript
import { carve, source } from "tilia";

type Counter = {
  count: number;
  double: number;
  add: (count: number) => void;
};

type Service = {
  fetchCount: () => (previous: number, set: (value: number) => void) => void;
  updateCount: (next: number, rollback: () => void) => void;
};

const double = (self: Counter): number => self.count * 2;
const add =
  (service: Service) =>
  (self: Counter) =>
  (count: number): void => {
    const prevValue = self.count;
    self.count += count;
    service.updateCount(self.count, () => (self.count = prevValue));
  };

const makeCounter = (service: Service) =>
  carve<Counter>(({ derived }) => ({
    count: source(0, service.fetchCount()),
    double: derived(double),
    add: derived(add(service)),
  }));

const feature = makeCounter(service);
feature.add(4);
```

```rescript
open Tilia

type counter = {
  mutable count: int,
  double: int,
  add: int => unit,
}

type service = {
  fetchCount: (int, int => unit) => unit,
  updateCount: (int, unit => unit) => unit,
}

let double = (self: counter) => self.count * 2
let add = (service: service) => (self: counter) => (count: int) => {
  let prevValue = self.count
  self.count += count
  service.updateCount(self.count, () => self.count = prevValue)
}

let makeCounter = service =>
  carve(({derived}) => {
    count: source(0, service.fetchCount),
    double: derived(double),
    add: derived(add(service)),
  })

let feature = makeCounter(service)
feature.add(4)
```

### Suggested file organization

```text
[feature-name]
  actions.ts    // mutating functions
  computed.ts   // computed/derived helpers
  index.ts      // carve glue
  service.ts    // external dependencies
  type.ts       // feature type
```

</section>

<a id="observer-pattern"></a>

<section class="doc observe">

### Observation in practice

`observe` and `watch` react only to what was read in the last run. This keeps updates precise without manual subscription code.

```typescript
observe(() => {
  if (profile.showDetails) {
    console.log(profile.email);
  }
});

profile.email = "new@mail.com"; // no rerun while showDetails is false
profile.showDetails = true;     // rerun
profile.email = "another@mail.com"; // rerun now
```

```rescript
observe(() => {
  if profile.showDetails {
    Js.log(profile.email)
  }
})

profile.email = "new@mail.com" // no rerun while showDetails is false
profile.showDetails = true // rerun
profile.email = "another@mail.com" // rerun now
```

</section>

<a id="dependency-graph"></a>

<section class="doc computed">

### Dependency tracking (short version)

Tilia uses JavaScript `Proxy` under the hood. Reads register dependencies, writes notify observers, and dependencies are recalculated dynamically on each run.

For a full internal walkthrough, see the [**Deep Technical Reference**](#technical) section below.

</section>

### Before / After: feature isolation

#### Before: logic-heavy components

```typescript
const TodoList = () => {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [sort, setSort] = useState<"date" | "title">("date");

  const add = async (title: string) => {
    const prev = todos;
    const next = [...todos, { id: crypto.randomUUID(), title, done: false }];
    setTodos(next);
    try {
      await api.save(next);
    } catch {
      setTodos(prev);
    }
  };

  const list = [...todos].sort(sort === "date" ? byDate : byTitle);
  return (
    <div>
      <button onClick={() => add("New todo")}>Add</button>
      <button onClick={() => setSort(sort === "date" ? "title" : "date")}>Toggle sort</button>
      <ul>
        {list.map((todo) => (
          <li key={todo.id}>{todo.title}</li>
        ))}
      </ul>
    </div>
  );
};
```

```rescript
@react.component
let make = () => {
  let (todos, setTodos) = React.useState(() => [])
  let (sort, setSort) = React.useState(() => ByDate)

  let add = async title => {
    let prev = todos
    let next = Array.concat(todos, [{id: "tmp", title, done: false}])
    setTodos(_ => next)
    try {
      await Api.save(next)
    } catch {
    | _ => setTodos(_ => prev)
    }
  }

  let list = switch sort {
  | ByDate => todos->Array.toSorted(byDate)
  | ByTitle => todos->Array.toSorted(byTitle)
  }
  <div>
    <button onClick={_ => add("New todo")}>{React.string("Add")}</button>
    <button onClick={_ => setSort(_ => switch sort { | ByDate => ByTitle | ByTitle => ByDate })}>
      {React.string("Toggle sort")}
    </button>
    <ul>
      {list
      ->Array.map(todo => <li key={todo.id}>{React.string(todo.title)}</li>)
      ->React.array}
    </ul>
  </div>
}
```

#### After: domain in feature, view as display adapter

```typescript
// domain/todos/index.ts
const list = (self: Todos) =>
  [...self.data].sort(self.sort === "date" ? byDate : byTitle);

const add =
  (service: Service) =>
  (self: Todos) =>
  async (): Promise<void> => {
    const prevValue = self.data;
    const todo = { id: crypto.randomUUID(), title: "New todo", done: false };
    self.data = [...self.data, todo];
    service.createTodo(todo, () => (self.data = prevValue));
  };

const toggleSort = (self: Todos) => (): void => {
  self.sort = self.sort === "date" ? "title" : "date";
};

export const makeTodos = (service: Service) =>
  carve<Todos>(({ derived }) => ({
    sort: "date",
    list: derived(list),
    add: derived(add(service)),
    toggleSort: derived(toggleSort),
    // private
    data: source([], service.fetchTodos()),
  }));

// ui/TodoList.tsx (single component, global feature)
import { leaf } from "@tilia/react";
import { app } from "../../app";

const TodoList = leaf(() => {
  const todos = app.todos;
  return (
    <div>
      <button onClick={todos.add}>Add</button>
      <button onClick={todos.toggleSort}>Toggle sort</button>
      <ul>
        {todos.list.map((todo) => (
          <li key={todo.id}>{todo.title}</li>
        ))}
      </ul>
    </div>
  );
});
```

```rescript
/* domain/todos/index.res */
let list = (self: Todos.t) =>
  switch self.sort {
  | ByDate => self.data->Array.toSorted(byDate)
  | ByTitle => self.data->Array.toSorted(byTitle)
  }

let add = service => self => async () => {
  let prevValue = self.data
  let todo = {id: "tmp", title: "New todo", done: false}
  self.data = Array.concat(self.data, [todo])
  service.createTodo(todo, () => self.data = prevValue)
}

let toggleSort = self => () =>
  self.sort = switch self.sort {
  | ByDate => ByTitle
  | ByTitle => ByDate
  }

let makeTodos = service =>
  carve(({derived}) => {
    sort: ByDate,
    list: derived(list),
    add: derived(add(service)),
    toggleSort: derived(toggleSort),
    // private
    data: source([], service.fetchTodos),
  })

/* ui/TodoList.res (single component, global feature) */
open TiliaReact
let app = App.app

@react.component
let make = leaf(() => {
  let todos = app.todos
  <div>
    <button onClick={todos.add}>{React.string("Add")}</button>
    <button onClick={todos.toggleSort}>
      {React.string("Toggle sort")}
    </button>
    <ul>
      {todos.list
      ->Array.map(todo => <li key={todo.id}>{React.string(todo.title)}</li>)
      ->React.array}
    </ul>
  </div>
})
```

### Why this approach scales

- easier testing: helpers are plain functions and services are injected
- easier refactoring: UI and domain code evolve separately
- easier portability: same feature model can back web and React Native views
- better stability: optimistic writes have explicit rollback paths

</section>