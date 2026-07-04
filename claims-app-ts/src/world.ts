import { tilia } from "tilia";
import { makeLocal, makeRemote, type Local, type Network } from "./app/adapters";
import type { Claim } from "./app/claim";
import { createApp, type App } from "./app/createApp";
import type { User } from "./app/user";
import { seed } from "./server/seed";
import { makeServer, type Server } from "./server/server";

export type Pane = {
  user: User;
  network: Network;
  local: Local;
  app: App;
  reload(): void;
};

export type World = {
  server: Server;
  panes: Pane[];
  setLive(on: boolean): void;
};

// The whole demo: one simulated server, two logged-in adjusters. Each pane
// owns its network flag and device storage; reload rebuilds the app instance
// while both survive, demonstrating boot replay of the outbox.
export function makeWorld(claims: Claim[] = seed()): World {
  const server = makeServer(claims);
  const world: World = tilia({
    server,
    panes: [pane(server, { id: "ana", name: "Ana" }), pane(server, { id: "ben", name: "Ben" })],
    // Switching transport reconnects every online client: the network blip
    // marks live queries stale, so they re-run against the new mode
    // (one-shot fetches become subscriptions and vice versa).
    setLive(on: boolean) {
      server.live = on;
      for (const p of world.panes) {
        if (p.network.online) {
          p.network.online = false;
          p.network.online = true;
        }
      }
    },
  });
  return world;
}

function pane(server: Server, user: User): Pane {
  const network: Network = tilia({ online: true });
  const local = makeLocal();
  const boot = () => createApp({ user, remote: makeRemote(server, user.id, network), local });
  const p: Pane = tilia({
    user,
    network,
    local,
    app: boot(),
    reload() {
      p.app.dispose();
      p.app = boot();
    },
  });
  return p;
}
