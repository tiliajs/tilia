import { useTilia } from "@tilia/react";
import { Database } from "lucide-react";
import type { CSSProperties } from "react";
import type { Claim, ClaimQuery } from "../app/claim";
import type { Sub, Touch } from "../server/server";
import type { World } from "../world";
import { money, StatusBadge, tones } from "./kit";

export function ServerPane({ world }: { world: World }) {
  useTilia();
  const server = world.server;
  const claims = Object.values(server.rows).sort((a, b) => a.id.localeCompare(b.id));
  return (
    <section className="flex h-[38%] min-h-0 flex-col border-t border-line bg-shade/50">
      <header className="flex items-center gap-2 border-b border-line px-4 py-2">
        <Database size={14} strokeWidth={2.2} className="text-muted" />
        <span className="text-[13px] font-semibold">Server</span>
        <span className="text-[12px] text-muted">{claims.length} claims on file</span>
        <Mode live={server.live} change={world.setLive} />
        {server.live && <Subs subs={server.subs} />}
        <div className="ml-auto flex items-center gap-2">
          <span className="text-[12px] text-muted">Latency</span>
          <input
            type="range"
            min={0}
            max={3000}
            step={100}
            value={server.latency}
            onChange={(e) => (server.latency = Number(e.target.value))}
            className="w-36 accent-ink"
          />
          <span className="w-16 text-right font-mono text-[12px] text-muted">{server.latency} ms</span>
        </div>
      </header>
      <div className="grid min-h-0 flex-1 auto-rows-min grid-cols-4 gap-2.5 overflow-y-auto p-3">
        {claims.map((claim) => (
          <Card
            key={`${claim.id}:${server.touches[claim.id]?.seq ?? 0}`}
            claim={claim}
            touch={server.touches[claim.id]}
            editor={server.edits[claim.id]}
          />
        ))}
      </div>
    </section>
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

function Card({ claim, touch, editor }: { claim: Claim; touch: Touch | undefined; editor: string | undefined }) {
  const tone = touch ? tones[touch.by] : undefined;
  return (
    <div
      className={`rounded-md border border-line bg-card p-2.5
        ${touch ? (touch.kind === "write" ? "touch-write" : "touch-read") : ""}`}
      style={tone ? ({ "--tone": tone.strong, "--tone-soft": tone.soft } as CSSProperties) : undefined}
    >
      <div className="flex items-center gap-2">
        <span className="font-mono text-[11px] text-muted">{claim.id}</span>
        {editor && (
          <span
            title={`Last write: ${editor[0].toUpperCase()}${editor.slice(1)}`}
            className="h-1.5 w-1.5 rounded-full"
            style={{ backgroundColor: tones[editor]?.strong }}
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
  );
}
