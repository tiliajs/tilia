import { useTilia } from "@tilia/react";
import { Database, Settings2 } from "lucide-react";
import { useState, type CSSProperties } from "react";
import type { Claim, ClaimQuery } from "../app/claim";
import type { Sub, Touch } from "../server/server";
import type { Settings, World } from "../world";
import { Button, Field, money, StatusBadge, tones } from "./kit";

const view = (value: number) =>
  Number.isInteger(value) ? value.toString() : value.toFixed(2).replace(/\.?0+$/, "");

const copy = (settings: Settings): Settings => ({
  latency: settings.latency,
});

const summary = (settings: Settings) => `latency ${view(settings.latency)} ms`;

const timestamp = new Intl.DateTimeFormat(undefined, {
  year: "numeric",
  month: "short",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
});

export function ServerPane({ world }: { world: World }) {
  useTilia();
  const server = world.server;
  const claims = Object.values(server.rows).sort((a, b) => a.id.localeCompare(b.id));
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState<Settings>(() => copy(world.settings));
  const openSettings = () => {
    setDraft(copy(world.settings));
    setOpen((current) => !current);
  };
  const closeSettings = () => setOpen(false);
  const applySettings = () => {
    world.configure(draft);
    closeSettings();
  };
  return (
    <section className="flex h-full min-h-0 flex-col bg-shade/50">
      <header className="flex items-center gap-2 border-b border-line px-4 py-2">
        <Database size={14} strokeWidth={2.2} className="text-muted" />
        <span className="text-[13px] font-semibold">Server</span>
        <span className="text-[12px] text-muted">{claims.length} claims on file</span>
        <Mode live={server.live} change={world.setLive} />
        {server.live && <Subs subs={server.subs} />}
        <Time world={world} />
        <div className="relative ml-auto">
          <button
            type="button"
            className="inline-flex items-center gap-2 border-0 bg-transparent px-0 py-1 text-[12px] text-muted transition-colors duration-150 hover:text-ink"
            onClick={openSettings}
            title="Open simulation settings"
          >
            <span className="inline-flex h-5 w-5 items-center justify-center rounded-md border border-line bg-card">
              <Settings2 size={13} strokeWidth={2.1} />
            </span>
            <span className="font-mono text-ink">{summary(world.settings)}</span>
          </button>
          {open && (
            <SettingsPopup
              draft={draft}
              setDraft={setDraft}
              close={closeSettings}
              apply={applySettings}
            />
          )}
        </div>
      </header>
      <div className="grid min-h-0 flex-1 auto-rows-min grid-cols-4 gap-2.5 overflow-y-auto p-3">
        {claims.map((claim) => (
          <Card
            key={`${claim.id}:${server.touches[claim.id]?.seq ?? 0}`}
            claim={claim}
            touch={server.touches[claim.id]}
          />
        ))}
      </div>
    </section>
  );
}

function SettingsPopup({
  draft,
  setDraft,
  close,
  apply,
}: {
  draft: Settings;
  setDraft: (next: (current: Settings) => Settings) => void;
  close: () => void;
  apply: () => void;
}) {
  const change = (key: keyof Settings, value: number) => {
    setDraft((current) => ({ ...current, [key]: value }));
  };
  return (
    <div className="absolute right-0 bottom-[calc(100%+0.5rem)] z-30 w-100 rounded-md border border-line bg-card p-4 shadow-xl">
      <div className="mb-3">
        <div className="text-[13px] font-semibold text-ink">Simulation settings</div>
        <p className="mt-1 text-[12px] leading-relaxed text-muted">
          Tune network latency for local and remote adaptor calls.
        </p>
      </div>

      <div className="space-y-3">
        <section className="rounded-md border border-line/70 bg-shade/40 p-3">
          <div className="mb-1 text-[12px] font-semibold text-ink">Network</div>
          <Field label={`Network latency per server call (${view(draft.latency)} ms)`}>
            <input
              className="settings-slider"
              type="range"
              min={0}
              max={3000}
              step={50}
              value={draft.latency}
              onChange={(e) => change("latency", Number(e.target.value))}
            />
          </Field>
        </section>

      </div>

      <div className="mt-4 flex justify-end gap-2">
        <Button kind="quiet" onClick={close}>
          Cancel
        </Button>
        <Button kind="primary" onClick={apply}>
          Apply settings
        </Button>
      </div>
    </div>
  );
}

function Time({ world }: { world: World }) {
  const now = world.clock.value;
  return (
    <div className="ml-2 flex items-center gap-1">
      <time className="mr-1 font-mono text-[11px] text-muted" dateTime={new Date(now).toISOString()}>
        Fake time {timestamp.format(now)}
      </time>
      <Button kind="quiet" title="Advance fake time by 10 seconds" onClick={() => world.advance(10 * 1000)}>
        +10 s
      </Button>
      <Button kind="quiet" title="Advance fake time by 10 minutes" onClick={() => world.advance(10 * 60 * 1000)}>
        +10 m
      </Button>
      <Button kind="quiet" title="Advance fake time by 10 days" onClick={() => world.advance(10 * 24 * 60 * 60 * 1000)}>
        +10 d
      </Button>
    </div>
  );
}

function Mode({ live, change }: { live: boolean; change: (on: boolean) => void }) {
  const styles = (active: boolean) =>
    `rounded px-2 py-0.5 text-[12px] font-medium transition-colors duration-150
     ${active ? "bg-card text-ink shadow-sm" : "text-muted hover:text-ink"}`;
  return (
    <div className="ml-2 flex items-center gap-0.5 rounded-md border border-line bg-shade p-0.5">
      <button type="button" className={styles(!live)} onClick={() => change(false)}>
        Polling
      </button>
      <button type="button" className={styles(live)} onClick={() => change(true)}>
        Live
      </button>
    </div>
  );
}

const label = (query: ClaimQuery) => {
  const parts: string[] = [];
  if (query.status) parts.push(`status = ${query.status}`);
  if (query.adjuster) parts.push(`adjuster = ${query.adjuster}`);
  return parts.length > 0 ? parts.join(", ") : "all claims";
};

// Registered live queries, one chip per subscription; a chip pulses in the
// client's color when a write pushes a new result to it.
function Subs({ subs }: { subs: Sub[] }) {
  return (
    <div className="flex min-w-0 items-center gap-1.5 overflow-x-auto">
      {subs.map((sub) => {
        const tone = tones[sub.client];
        return (
          <span
            key={`${sub.id}:${sub.seq}`}
            className="touch-read shrink-0 rounded-md border border-line bg-card px-1.5 py-0.5 font-mono text-[11px] text-muted"
            style={tone ? ({ "--tone": tone.strong, "--tone-soft": tone.soft } as CSSProperties) : undefined}
          >
            <span className="font-medium capitalize" style={{ color: tone?.strong }}>
              {sub.client}
            </span>
            {" · "}
            {label(sub.query)}
          </span>
        );
      })}
    </div>
  );
}

function Card({ claim, touch }: { claim: Claim; touch: Touch | undefined }) {
  const read = touch?.read;
  const write = touch?.write;
  const readTone = read ? tones[read.by] : undefined;
  const writeTone = write ? tones[write.by] : undefined;
  const readLive = !!(touch && read && touch.seq === read.seq);
  const writeLive = !!(touch && write && touch.seq === write.seq);
  return (
    <div
      className={`rounded-md border border-line bg-card ${readLive ? "touch-read" : ""}`}
      style={readTone ? ({ "--tone": readTone.strong, "--tone-soft": readTone.soft } as CSSProperties) : undefined}
    >
      <div
        className={`rounded-[inherit] p-2.5 ${writeLive ? "touch-write" : ""}`}
        style={writeTone ? ({ "--tone": writeTone.strong, "--tone-soft": writeTone.soft } as CSSProperties) : undefined}
      >
        <div className="flex items-center gap-2">
          <span className="font-mono text-[11px] text-muted">{claim.id}</span>
          {writeLive && write && (
            <span
              title={`Write by ${write.by[0].toUpperCase()}${write.by.slice(1)}`}
              className="dot-write h-1.5 w-1.5 rounded-full"
              style={{ backgroundColor: writeTone?.strong }}
            />
          )}
          <span className="ml-auto font-mono text-[10px] text-faint">v{claim.version}</span>
        </div>
        <div className="mt-0.5 truncate text-[12px] font-medium">{claim.claimant || "—"}</div>
        <div className="truncate text-[11px] text-muted">
          {claim.peril}
          {claim.city ? ` · ${claim.city}` : ""}
        </div>
        <div className="mt-1.5 flex items-center gap-1.5">
          <StatusBadge status={claim.status} />
          {claim.adjuster && (
            <span
              className="text-[11px] font-medium"
              style={{ color: tones[claim.adjuster.toLowerCase()]?.strong }}
            >
              {claim.adjuster}
            </span>
          )}
          {claim.estimate > 0 && (
            <span className="ml-auto font-mono text-[11px] text-muted">{money(claim.estimate)}</span>
          )}
        </div>
      </div>
    </div>
  );
}
