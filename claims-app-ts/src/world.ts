import { signal, tilia, type Signal } from "tilia";
import {
  makeLocal,
  makeRemote,
  type AdaptorCall,
  type AdaptorLog,
  type Local,
  type Network,
} from "./app/adapters";
import type { Claim } from "./app/claim";
import { createApp, type App } from "./app/createApp";
import type { User } from "./app/user";
import { seed } from "./server/seed";
import { makeServer, type Server } from "./server/server";
import type { Preview } from "./ui/preview";

export type Pane = {
  user: User;
  network: Network;
  log: AdaptorLog;
  local: Local;
  app: App;
  preview?: Preview;
  reloading: boolean;
  reload(): Promise<void>;
  rebuild(): void;
};

export type Settings = {
  latency: number;
};

export type Clock = Signal<number>;

export type World = {
  server: Server;
  settings: Settings;
  clock: Clock;
  panes: Pane[];
  setLive(on: boolean): void;
  configure(next: Partial<Settings>): void;
  advance(milliseconds: number): void;
};

const clean = (value: number, fallback: number, min: number, max: number) => {
  if (!Number.isFinite(value)) return fallback;
  return Math.min(max, Math.max(min, value));
};

// The whole demo: one simulated server, two logged-in adjusters. Each pane
// owns its network flag and device storage; reload rebuilds the app instance
// while both survive, demonstrating boot replay of the outbox.
export function makeWorld(claims: Claim[] = seed(), now: () => number = Date.now): World {
  const server = makeServer(claims);
  const settings: Settings = tilia({ latency: 800 });
  const [clock, setClock] = signal(now());
  server.latency = settings.latency;
  const world: World = tilia({
    server,
    settings,
    clock,
    panes: [
      pane(server, { id: "ana", name: "Ana" }, () => clock.value),
      pane(server, { id: "ben", name: "Ben" }, () => clock.value),
    ],
    setLive(on: boolean) {
      if (server.live === on) return;
      server.live = on;
      for (const p of world.panes) p.rebuild();
    },
    configure(next) {
      const latency = clean(next.latency ?? settings.latency, settings.latency, 0, 10000);
      settings.latency = latency;
      server.latency = latency;
    },
    advance(milliseconds) {
      const amount = clean(milliseconds, 0, 0, Number.MAX_SAFE_INTEGER);
      setClock(clock.value + amount);
      for (const p of world.panes) p.app.tick();
    },
  });
  return world;
}

function pane(server: Server, user: User, now: () => number): Pane {
  const [online] = signal(true);
  const calls = tilia<AdaptorCall[]>([]);
  const network: Network = { online };
  const log: AdaptorLog = { calls };
  const local = makeLocal(log);
  let restarting: Promise<void> | undefined;
  const boot = () =>
    createApp({
      user,
      remote: makeRemote(server, user.id, network, log),
      local,
      refresh: 30_000,
      memory: 120_000,
      now,
    });
  const p: Pane = tilia({
    user,
    network,
    log,
    local,
    app: boot(),
    preview: undefined,
    reloading: false,
    reload() {
      if (restarting) return restarting;
      const tab = p.app.claims.tab;
      p.app.dispose();
      p.preview = undefined;
      p.reloading = true;
      calls.splice(0);
      restarting = new Promise((resolve) => {
        setTimeout(() => {
          p.app = boot();
          p.app.claims.filter(tab);
          p.reloading = false;
          restarting = undefined;
          resolve();
        }, 500);
      });
      return restarting;
    },
    rebuild() {
      const tab = p.app.claims.tab;
      p.app.dispose();
      p.app = boot();
      p.app.claims.filter(tab);
    },
  });
  return p;
}
