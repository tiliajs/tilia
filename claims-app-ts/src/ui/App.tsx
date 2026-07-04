import type { World } from "../world";
import { ServerPane } from "./ServerPane";
import { UserPane } from "./UserPane";

export function App({ world }: { world: World }) {
  return (
    <div className="flex h-screen flex-col">
      <div className="grid min-h-0 flex-1 grid-cols-2 divide-x divide-line">
        <UserPane pane={world.panes[0]} />
        <UserPane pane={world.panes[1]} />
      </div>
      <ServerPane world={world} />
    </div>
  );
}
