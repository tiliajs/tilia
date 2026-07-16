import { useRef, useState, type PointerEvent as ReactPointerEvent } from "react";
import type { World } from "../world";
import { ServerPane } from "./ServerPane";
import { DebugPane, UserPane } from "./UserPane";

const handle = 6;
const minimum = 0.1;

function Resize({
  label,
  move,
}: {
  label: string;
  move: (clientY: number) => void;
}) {
  const down = (event: ReactPointerEvent<HTMLDivElement>) => {
    event.currentTarget.setPointerCapture(event.pointerId);
    document.body.style.cursor = "row-resize";
    document.body.style.userSelect = "none";
  };
  const drag = (event: ReactPointerEvent<HTMLDivElement>) => {
    if (event.currentTarget.hasPointerCapture(event.pointerId)) move(event.clientY);
  };
  const up = (event: ReactPointerEvent<HTMLDivElement>) => {
    if (event.currentTarget.hasPointerCapture(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
    document.body.style.cursor = "";
    document.body.style.userSelect = "";
  };
  return (
    <div
      role="separator"
      aria-label={label}
      aria-orientation="horizontal"
      className="group flex cursor-row-resize items-center bg-line/60"
      onPointerDown={down}
      onPointerMove={drag}
      onPointerUp={up}
      onPointerCancel={up}
    >
      <div className="h-px w-full bg-line transition-colors group-hover:bg-muted" />
    </div>
  );
}

export function App({ world }: { world: World }) {
  const root = useRef<HTMLDivElement>(null);
  const [sizes, setSizes] = useState({ client: 0.55, debug: 0.25 });
  const measure = () => {
    const rect = root.current?.getBoundingClientRect();
    if (!rect) return;
    return { top: rect.top, usable: rect.height - handle * 2 };
  };
  const moveClient = (clientY: number) => {
    const box = measure();
    if (!box) return;
    setSizes((current) => {
      const bottom = current.client + current.debug;
      const client = Math.min(bottom - minimum, Math.max(0.2, (clientY - box.top) / box.usable));
      return { client, debug: bottom - client };
    });
  };
  const moveDebug = (clientY: number) => {
    const box = measure();
    if (!box) return;
    setSizes((current) => {
      const bottom = Math.min(0.9, Math.max(current.client + minimum, (clientY - box.top - handle) / box.usable));
      return { ...current, debug: bottom - current.client };
    });
  };
  return (
    <div
      ref={root}
      className="grid h-screen overflow-hidden"
      style={{
        gridTemplateRows: `${sizes.client}fr ${handle}px ${sizes.debug}fr ${handle}px ${
          1 - sizes.client - sizes.debug
        }fr`,
      }}
    >
      <div className="grid min-h-0 grid-cols-2 divide-x divide-line">
        <UserPane pane={world.panes[0]} />
        <UserPane pane={world.panes[1]} />
      </div>
      <Resize label="Resize clients and debug panels" move={moveClient} />
      <div className="grid min-h-0 grid-cols-2 divide-x divide-line">
        <DebugPane pane={world.panes[0]} />
        <DebugPane pane={world.panes[1]} />
      </div>
      <Resize label="Resize debug and server panels" move={moveDebug} />
      <ServerPane world={world} />
    </div>
  );
}
