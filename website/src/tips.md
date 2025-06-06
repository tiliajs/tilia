# Some tips and tricks

## Mutating during render (is `sort` of bad)

Mutating during render should (be avoided) because it can lead to infinite loops.

For example, the `sort` function in JS mutates the array in place which means that the component is making updates to the array itself while rendering and this can cause the component to re-render infinitely.

```tsx
function MyBadList() {
  useTilia();

  return (
    <div>
      <ul>
        {
          //       ⬇️ 💥 this mutates the projects.list array
          app.list.sort((a, b) => a.name.localeCompare(b.name))
            .map((project) => (
              <li key={project.id}>{project.name}</li>
            ))
        )}
      </ul>
    </div>
  )
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
        {[...app.list]
          // ⬇️ now the sort is done in a copy of the array
          .sort((a, b) => a.name.localeCompare(b.name))
          .map((project) => (
            <li key={project.id}>{project.name}</li>
          ))}
      </ul>
    </div>
  );
}
```

Or use a derived array to cache the sorted list.

```tsx
import { useTilia } from "@tilia/react";
import { derived } from "tilia";

const sortedList = derived(() =>
  [...app.list].sort((a, b) => a.name.localeCompare(b.name))
);

function MyGreatList() {
  useTilia();

  return (
    <div>
      <ul>
        {
          // ⬇️ ✅ Now the sort is only computed when needed
          sortedList.value.map((project) => (
            <li key={project.id}>{project.name}</li>
          ))
        }
      </ul>
    </div>
  );
}
```

But in exceptional cases, you need to mutate during the render phase, for example if you are using a translation library and need to push some observed key in a store. This is fine.

```tsx
function MyGreatList() {
  useTilia();
  const t = tree.translator;

  return (
    <div>
      {
        //  ⬇️ ✅ If t needs to mutate state to record viewed keys, it is fine.
      }
      <div>{t("toys:list.title")}</div>
      ...
    </div>
  );
}
```

The library is built to support mutating during render. Just make sure to avoid ∞ loops.

## Forgeting to call "useTilia" inside components

`useTilia` sets which component is the current observer. If we forget to call it, the component will not be re-rendered on state changes.

State read by an untracked component will be recorded in the last tracked component. If this last component is an ancestor, this will work fine (but with excessive rendering of the ancestor instead of just the child).

```tsx
function ParentComponent() {
  useTilia();

  return <WeirdChildComponent toy={app.child.toy} />;
}

function WeirdChildComponent({ toy }: { toy: Toy }) {
  // We did not call `useTilia` and the toy.name is now watched by the parent.
  //
  // On toy.name change, the parent (and the child) will re-render.
  //                                   ⬇️ 🥺
  return <div>I like to play with {toy.name}</div>;
}
```

But if the last tracked component is a sibling, the child's value will be "stuck".

```tsx
function ParentComponent() {
  useTilia();

  return (
    <>
      <GoodAlice toy={app.alice.toy} />;
      <BadTina toy={app.tina.toy} />;
    </>
  );
}

function GoodAlice({ toy }: { toy: Toy }) {
  useTilia();

  return <div>I am a good child. I like {toy.name}</div>;
}

function BadTina({ toy }: { toy: Toy }) {
  // We did not call `useTilia`, Alice is the last observer.
  //
  // On toy.name changes, Alice will re-render (once) and Tina will be "stuck".
  //                                   ⬇️ 💥
  return <div>I like to play with {toy.name}</div>;
}
```

Make sure to call `useTilia` at the root of the components that consume connected tilia state.

## Moved or copied objects are not cloned

When you copy an object, the library will not clone it. This means that if you mutate the object, it will be reflected in the original object.

This is cool.

```ts
const alice = tilia({ name: "Alice" });
const bob = tilia({ name: "Bob" });

// Alice observer
observe(() => {
  console.log("Alice :", alice.name);
});

const app = tilia({
  list: [alice, bob],
});

app.selected = list[0];

// ⬇️ 🦄 This also mutates the original element in the array like a regular JS object.
//      It also triggers the Alice observer.
app.selected.name = "Anabel";
```

We mutated `app.selected.name` and the observer of `alice.name` was triggered, like it should be.
