import { createRoot } from "react-dom/client";
import "./index.css";
import { App } from "./ui/App";
import { makeWorld } from "./world";

const world = makeWorld();

// The library never starts timers: drive stale refresh and garbage
// collection from the app's own scheduler.
setInterval(() => {
  for (const pane of world.panes) pane.app.tick();
}, 2000);

createRoot(document.getElementById("root")!).render(<App world={world} />);
