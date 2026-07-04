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

export type Settings = {
  latency: number;
  refresh: number;
  liveRefresh: number;
  gc: number;
};

export type World = {
  server: Server;
  settings: Settings;
  panes: Pane[];
  setLive(on: boolean): void;
  configure(next: Partial<Settings>): void;
};

const clean = (value: number, fallback: number, min: number, max: number) => {
  if (!Number.isFinite(value)) return fallback;
  return Math.min(max, Math.max(min, value));
};

// The whole demo: one simulated server, two logged-in adjusters. Each pane
// owns its network flag and device storage; reload rebuilds the app instance
// while both survive, demonstrating boot replay of the outbox.
export function makeWorld(claims: Claim[] = seed()): World {
  const server = makeServer(claims);
  const settings: Settings = tilia({
    latency: 800,
    refresh: 30,
    liveRefresh: 60,
    gc: 120,
  });
  server.latency = settings.latency;
  const world: World = tilia({
    server,
    settings,
    panes: [pane(server, settings, { id: "ana", name: "Ana" }), pane(server, settings, { id: "ben", name: "Ben" })],
    // Switching transport rebuilds each app against the active refresh policy.
    setLive(on: boolean) {
      if (server.live === on) return;
      server.live = on;
      for (const p of world.panes) p.reload();
    },
    configure(next) {
      const latency = clean(next.latency ?? settings.latency, settings.latency, 0, 10000);
      const refresh = clean(next.refresh ?? settings.refresh, settings.refresh, 0.01, 3600);
      const liveRefresh = clean(next.liveRefresh ?? settings.liveRefresh, settings.liveRefresh, 0.01, 3600);
      const gc = clean(next.gc ?? settings.gc, settings.gc, 0.01, 3600);
      const queryChanged = refresh !== settings.refresh || liveRefresh !== settings.liveRefresh || gc !== settings.gc;
      settings.latency = latency;
      settings.refresh = refresh;
      settings.liveRefresh = liveRefresh;
      settings.gc = gc;
      server.latency = latency;
      if (queryChanged) {
        for (const p of world.panes) p.reload();
      }
    },
  });
  return world;
}

function pane(server: Server, settings: Settings, user: User): Pane {
  const network: Network = tilia({ online: true });
  const local = makeLocal();
  const boot = () =>
    createApp({
      user,
      remote: makeRemote(server, user.id, network),
      local,
      stale: server.live ? settings.liveRefresh : settings.refresh,
      gc: settings.gc,
    });
  const p: Pane = tilia({
    user,
    network,
    local,
    app: boot(),
    reload() {
      const tab = p.app.claims.tab;
      p.app.dispose();
      p.app = boot();
      p.app.claims.filter(tab);
    },
  });
  return p;
}
