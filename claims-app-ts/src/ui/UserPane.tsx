import { leaf, useTilia } from "@tilia/react";
import { CloudUpload, Plus, RotateCcw, Trash2, TriangleAlert, WifiOff } from "lucide-react";
import { useEffect, useState, type CSSProperties } from "react";
import { statuses, type Claim, type Status } from "../app/claim";
import type { ClaimsFeature, Tab } from "../app/features/claims/type";
import type { Pane } from "../world";
import { Button, Field, inputStyle, money, StatusBadge, Switch, tones } from "./kit";

const tabs: Tab[] = ["mine", "all", ...statuses];
type Canopy = { live: string[]; idle: string[] };

export const UserPane = leaf(function UserPane({ pane }: { pane: Pane }) {
  const tone = tones[pane.user.id];
  const claims = pane.app.claims;
  const online = pane.network.online;
  return (
    <section
      className="flex min-h-0 flex-col bg-paper"
      style={{ "--tone": tone.strong, "--tone-soft": tone.soft } as CSSProperties}
    >
      <header className="flex items-center gap-3 border-b border-line px-4 py-3">
        <span
          className="flex h-8 w-8 items-center justify-center rounded-full bg-(--tone) text-[14px] font-semibold text-card"
        >
          {pane.user.name[0]}
        </span>
        <div className="min-w-0">
          <div className="text-[14px] font-semibold leading-tight">{pane.user.name}</div>
          <div className="text-[12px] text-muted leading-tight">Field adjuster</div>
        </div>
        <div className="ml-auto flex items-center gap-3">
          {claims.pending > 0 && (
            <span className="inline-flex items-center gap-1 rounded-md bg-warn-bg px-1.5 py-0.5 text-[11px] font-medium text-warn-fg">
              <CloudUpload size={12} strokeWidth={2.2} />
              {claims.pending} to sync
            </span>
          )}
          {!online && (
            <span className="inline-flex items-center gap-1 text-[12px] font-medium text-warn-fg">
              <WifiOff size={13} strokeWidth={2.2} />
              Offline
            </span>
          )}
          <Switch on={online} change={(on) => (pane.network.online = on)} label="Network" />
          <Button kind="quiet" title="Reload the app (state is rebuilt from device storage)" onClick={pane.reload}>
            <RotateCcw size={13} strokeWidth={2.2} />
          </Button>
        </div>
      </header>

      {claims.rejected.length > 0 && (
        <div className="flex items-center gap-2 border-b border-line bg-warn-bg px-4 py-2 text-[12px] text-warn-fg">
          <TriangleAlert size={13} strokeWidth={2.2} />
          <span className="min-w-0 flex-1">
            Sync refused: {claims.rejected[0].message}. The office value was restored.
          </span>
          <Button kind="quiet" onClick={claims.dismiss}>
            Dismiss
          </Button>
        </div>
      )}

      <div className="flex items-center gap-1 border-b border-line px-4">
        {tabs.map((tab) => (
          <button
            key={tab}
            type="button"
            onClick={() => claims.filter(tab)}
            className={`-mb-px border-b-2 px-2 py-2 text-[13px] capitalize transition-colors duration-150
              ${claims.tab === tab ? "border-(--tone) font-medium text-ink" : "border-transparent text-muted hover:text-ink"}`}
          >
            {tab}
          </button>
        ))}
        <div className="ml-auto py-1.5">
          <Button kind="ghost" onClick={claims.create}>
            <Plus size={13} strokeWidth={2.2} />
            New claim
          </Button>
        </div>
      </div>

      <CanopyView pane={pane} />

      {claims.editing ? <Editor claims={claims} /> : <List claims={claims} />}
    </section>
  );
});

const keyText = (key: string): string => {
  if (key === "{}") return "all claims";
  try {
    const query = JSON.parse(key) as { status?: string; adjuster?: string };
    const parts: string[] = [];
    if (query.adjuster) parts.push(`adjuster = ${query.adjuster}`);
    if (query.status) parts.push(`status = ${query.status}`);
    return parts.length > 0 ? parts.join(", ") : key;
  } catch {
    return key;
  }
};

function CanopyView({ pane }: { pane: Pane }) {
  const [, refresh] = useState(0);
  useEffect(() => {
    const timer = setInterval(() => refresh((current) => current + 1), 500);
    return () => clearInterval(timer);
  }, []);
  const canopy: Canopy = pane.app.canopy();
  const live = [...canopy.live].sort();
  const idle = [...canopy.idle].sort();
  return (
    <div className="border-b border-line bg-shade/35 px-4 py-2">
      <div className="mb-1 text-[11px] font-semibold text-muted">Client query canopy</div>
      <div className="flex flex-wrap items-center gap-1.5">
        <span className="text-[11px] font-medium text-ink">Live {live.length}</span>
        {live.length === 0 ? (
          <span className="text-[11px] text-faint">none</span>
        ) : (
          live.map((key) => (
            <span key={`live:${key}`} className="rounded-md border border-line bg-card px-1.5 py-0.5 text-[11px]">
              {keyText(key)}
            </span>
          ))
        )}
      </div>
      <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
        <span className="text-[11px] font-medium text-muted">Idle {idle.length}</span>
        {idle.length === 0 ? (
          <span className="text-[11px] text-faint">none</span>
        ) : (
          idle.map((key) => (
            <span
              key={`idle:${key}`}
              className="rounded-md border border-line/80 bg-shade px-1.5 py-0.5 text-[11px] text-muted"
            >
              {keyText(key)}
            </span>
          ))
        )}
      </div>
    </div>
  );
}

const List = leaf(function List({ claims }: { claims: ClaimsFeature }) {
  const list = claims.list;
  if (list === "loading" || list === "notFound") {
    return (
      <div className="flex flex-col gap-2 p-4">
        {[0, 1, 2].map((i) => (
          <div key={i} className="h-11 animate-pulse rounded-md bg-shade" />
        ))}
      </div>
    );
  }
  if (list.data.length === 0) {
    return <div className="p-6 text-center text-[13px] text-muted">No claims in this view.</div>;
  }
  return (
    <ul className="min-h-0 flex-1 overflow-y-auto">
      {list.data.map((claim) => (
        <Row key={claim.id} claim={claim} claims={claims} />
      ))}
    </ul>
  );
});

function Row({ claim, claims }: { claim: Claim; claims: ClaimsFeature }) {
  return (
    <li
      className="group grid cursor-pointer items-center gap-x-3 border-b border-line px-4 py-2.5
        grid-cols-[5rem_minmax(0,1fr)_7.5rem_5.5rem_8.75rem]
        transition-colors duration-150 hover:bg-shade/70"
      onClick={() => claims.edit(claim)}
    >
      <div className="font-mono text-[12px] text-muted">{claim.id}</div>
      <div className="min-w-0 flex-1">
        <div className="truncate text-[13px] font-medium">{claim.claimant || "—"}</div>
        <div className="truncate text-[12px] text-muted">
          {claim.peril}
          {claim.city ? ` · ${claim.city}` : ""}
        </div>
      </div>
      <div className="justify-self-end text-right font-mono text-[12px] text-muted">
        {claim.estimate > 0 ? money(claim.estimate) : ""}
      </div>
      <div className="flex justify-end">
        <StatusBadge status={claim.status} />
      </div>
      <div
        className="flex justify-self-end items-center gap-1 opacity-0 transition-opacity duration-150 group-hover:opacity-100"
        onClick={(e) => e.stopPropagation()}
      >
        <Action claim={claim} claims={claims} />
        <Button kind="quiet" title="Remove claim" onClick={() => claims.remove(claim)}>
          <Trash2 size={13} strokeWidth={2} />
        </Button>
      </div>
    </li>
  );
}

function Action({ claim, claims }: { claim: Claim; claims: ClaimsFeature }) {
  switch (claim.status) {
    case "new":
      return (
        <Button kind="ghost" onClick={() => claims.take(claim)}>
          Take
        </Button>
      );
    case "assigned":
      return (
        <Button kind="ghost" onClick={() => claims.edit(claim)}>
          Inspect
        </Button>
      );
    case "inspected":
      return (
        <Button kind="ghost" onClick={() => claims.close(claim)}>
          Close
        </Button>
      );
    case "closed":
      return null;
  }
}

function Editor({ claims }: { claims: ClaimsFeature }) {
  useTilia();
  const draft = claims.editing;
  if (!draft) return null;
  return (
    <div className="min-h-0 flex-1 overflow-y-auto p-4">
      <div className="rounded-md border border-line bg-card p-4">
        <div className="mb-4 flex items-baseline gap-2">
          <span className="font-mono text-[13px] text-muted">{draft.id}</span>
          <span className="text-[14px] font-semibold">{draft.claimant || "New claim"}</span>
          <span className="ml-auto">
            <StatusBadge status={draft.status} />
          </span>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Claimant">
            <input
              className={inputStyle}
              value={draft.claimant}
              placeholder="M. Example"
              onChange={(e) => (draft.claimant = e.target.value)}
            />
          </Field>
          <Field label="City">
            <input
              className={inputStyle}
              value={draft.city}
              placeholder="Lausanne"
              onChange={(e) => (draft.city = e.target.value)}
            />
          </Field>
          <Field label="Peril">
            <input
              className={inputStyle}
              value={draft.peril}
              placeholder="Water damage"
              onChange={(e) => (draft.peril = e.target.value)}
            />
          </Field>
          <Field label="Status">
            <select
              className={`${inputStyle} capitalize`}
              value={draft.status}
              onChange={(e) => (draft.status = e.target.value as Status)}
            >
              {statuses.map((status) => (
                <option key={status} value={status}>
                  {status}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Estimate (CHF)">
            <input
              className={`${inputStyle} font-mono`}
              type="number"
              min={0}
              step={100}
              value={draft.estimate}
              onChange={(e) => (draft.estimate = Number(e.target.value) || 0)}
            />
          </Field>
        </div>
        <div className="mt-3">
          <Field label="Notes">
            <textarea
              className={`${inputStyle} min-h-20 resize-y`}
              value={draft.notes}
              placeholder="Findings, next steps…"
              onChange={(e) => (draft.notes = e.target.value)}
            />
          </Field>
        </div>
        <div className="mt-4 flex justify-end gap-2">
          <Button kind="ghost" onClick={claims.cancel}>
            Cancel
          </Button>
          <Button kind="primary" onClick={claims.commit}>
            Save
          </Button>
        </div>
      </div>
    </div>
  );
}
