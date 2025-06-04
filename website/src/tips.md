# Some tips and tricks

## Beware of `sort`

The `sort` function in JS mutates the array in place which means that the component is making updates to the array itself while rendering and this will cause the component to re-render infinitely.

```tsx
function MyBadList() {
  useTilia();

  return (
    <div>
      <ul>
        {
          //                ⬇️ 💥 this mutates the projects.list array
          app.projects.list
            .sort((a, b) => a.name.localeCompare(b.name))
            .map((project) => (
              <li key={project.id}>{project.name}</li>
            ))
        }
      </ul>
    </div>
  );
}
```

Instead, you can either use a quick fix like this:

```tsx
import { useTilia } from "@tilia/react";

function MyOkList() {
  useTilia();

  return (
    <div>
      <ul>
        {
          //                        ⬇️ now the sort is done in a copy of the array
          app.projects.list
            .slice()
            .sort((a, b) => a.name.localeCompare(b.name))
            .map((project) => (
              <li key={project.id}>{project.name}</li>
            ))
        }
      </ul>
    </div>
  );
}
```

Or use a derived array to cache the sorted list.

```tsx
import { useTilia } from "@tilia/react";
import { derived } from "tilia";

const sortedProjects = derived(() =>
  app.projects.list.slice().sort((a, b) => a.name.localeCompare(b.name))
);

function MyGreatList() {
  useTilia();

  return (
    <div>
      <ul>
        {
          // ⬇️ ✅ Now the sort is only computed when needed
          sortedProjects.value.map((project) => (
            <li key={project.id}>{project.name}</li>
          ))
        }
      </ul>
    </div>
  );
}
```

To avoid this, use the `slice` function to create a copy of the array.
