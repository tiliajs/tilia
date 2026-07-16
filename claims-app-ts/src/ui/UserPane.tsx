import { leaf, useTilia } from "@tilia/react";
import type { Rejection } from "@tilia/query";
import { CloudUpload, Plus, RotateCcw, Trash2, TriangleAlert, WifiOff } from "lucide-react";
import { useEffect, useState, type CSSProperties } from "react";
import { fields, statuses, type Claim, type ClaimField, type Status } from "../app/claim";
import type { ClaimsFeature, Tab } from "../app/features/claims/type";
import type { Pane } from "../world";
import { Button, Field, inputStyle, money, StatusBadge, Switch, tones } from "./kit";

const tabs: Tab[] = ["mine", "all", ...statuses];
type Canopy = { live: string[]; idle: string[] };

const rejectionMessage = (rejection: Rejection<Claim>) => {
  switch (rejection.TAG) {
    case "CreateConflict":
      return "Create conflicted with an office claim. The office value was restored.";
    case "UpdateConflict":
      return "Conflict: same field edit.";
    case "RemoveConflict":
      return "Remove conflicted with an office change. The office value was restored.";
    case "CreateFailed":
    case "RemoveFailed":
      return `Sync refused: ${rejection._1}. The office value was restored.`;
    case "UpdateFailed":
      return `Sync refused: ${rejection._2}. The office value was restored.`;
  }
};

const rejectionId = (rejection: Rejection<Claim>) => {
  switch (rejection.TAG) {
    case "UpdateConflict":
    case "UpdateFailed":
      return rejection._1.id;
    default:
      return rejection._0.id;
  }
};

export const UserPane = leaf(function UserPane({ pane }: { pane: Pane }) {
  const tone = tones[pane.user.id];
  const claims = pane.app.claims;
  const online = pane.network.online.value;
  const previewOutbox = () => {
    const values = [...(pane.local.entries.get("outbox")?.values() ?? [])].map(
      (value) =>
        JSON.parse(value) as {
          seq: number;
          op: { op: "upsert"; value: Claim } | { op: "remove"; id: string };
        }
    );
    const text = values
      .map(({ seq, op }) =>
        op.op === "remove"
          ? `#${seq} remove ${op.id}`
          : `#${seq} upsert ${op.value.id} · ${op.value.status}${op.value.adjuster ? ` · ${op.value.adjuster}` : ""}`
      )
      .join("\n");
    pane.preview = { title: `Outbox · ${claims.pending} pending`, value: values, text };
  };
  if (pane.reloading) {
    return (
      <section
        aria-label={`${pane.user.name} client restarting`}
        className="flex min-h-0 flex-col items-center justify-center gap-3 bg-off text-muted"
      >
        <span className="restart-animal font-mono text-[44px] leading-none" aria-hidden="true">
          <span className="restart-animal-open">ʕ•ᴥ•ʔ</span>
          <span className="restart-animal-closed">ʕ-ᴥ-ʔ</span>
        </span>
        <span className="text-[14px] font-medium">Restarting client…</span>
      </section>
    );
  }
  return (
    <section
      className="relative flex min-h-0 flex-col bg-paper"
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
            <span
              className="inline-flex cursor-help items-center gap-1 rounded-md bg-warn-bg px-1.5 py-0.5 text-[11px] font-medium text-warn-fg"
              tabIndex={0}
              onPointerEnter={previewOutbox}
              onPointerLeave={() => (pane.preview = undefined)}
              onFocus={previewOutbox}
              onBlur={() => (pane.preview = undefined)}
            >
              <CloudUpload size={12} strokeWidth={2.2} />
              {claims.pending} pending
            </span>
          )}
          {!online && (
            <span className="inline-flex items-center gap-1 text-[12px] font-medium text-warn-fg">
              <WifiOff size={13} strokeWidth={2.2} />
              Offline
            </span>
          )}
          <Switch on={online} change={(on) => (pane.network.online.value = on)} label="Network" />
          <Button
            kind="quiet"
            title="Reload the app (state is rebuilt from device storage)"
            onClick={() => void pane.reload()}
          >
            <RotateCcw size={13} strokeWidth={2.2} />
          </Button>
        </div>
      </header>

      {claims.rejected.slice(0, 1).map((rejection) => (
        <div
          key={`${rejection.TAG}:${rejectionId(rejection)}`}
          className="flex items-center gap-2 border-b border-line bg-warn-bg px-4 py-2 text-[12px] text-warn-fg"
        >
          <TriangleAlert size={13} strokeWidth={2.2} />
          <span className="min-w-0 flex-1">{rejectionMessage(rejection)}</span>
          {rejection.TAG === "UpdateConflict" ? (
            <Button
              kind="quiet"
              onClick={() => {
                const theirs = pane.local.rows.get(rejection._1.id);
                if (theirs) claims.resolve(rejection, theirs);
              }}
            >
              Resolve
            </Button>
          ) : (
            <Button kind="quiet" onClick={() => claims.dismiss(rejection)}>
              Dismiss
            </Button>
          )}
        </div>
      ))}

      {claims.resolution && <Resolver claims={claims} />}

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

const callLabel = (label: string | undefined) => {
  if (!label) return undefined;
  if (label.startsWith("query:")) {
    const key = label.slice("query:".length);
    return key === "*" ? "all queries" : `query · ${keyText(key)}`;
  }
  if (label.startsWith("outbox:")) {
    const key = label.slice("outbox:".length);
    return key === "*" ? "all changes" : `change · #${key}`;
  }
  return label;
};

function CallValue({ pane, title, value }: { pane: Pane; title: string; value: unknown }) {
  if (value === undefined) {
    return (
      <span className="ml-1 inline-block align-middle font-mono text-[14px] leading-none text-faint" title="No value">
        ∅
      </span>
    );
  }
  return (
    <span
      className="ml-1 inline-block h-4 w-5 cursor-help rounded border border-line bg-card text-center font-mono text-[13px] leading-[13px] align-middle text-muted hover:border-faint hover:text-ink"
      tabIndex={0}
      aria-label={`Preview ${title} value`}
      onPointerEnter={() => (pane.preview = { title, value })}
      onPointerLeave={() => (pane.preview = undefined)}
      onFocus={() => (pane.preview = { title, value })}
      onBlur={() => (pane.preview = undefined)}
    >
      ·
    </span>
  );
}

export function DebugPane({ pane }: { pane: Pane }) {
  useTilia();
  const [, refresh] = useState(0);
  useEffect(() => {
    const timer = setInterval(() => refresh((current) => current + 1), 500);
    return () => clearInterval(timer);
  }, []);
  const canopy: Canopy = pane.app.canopy();
  const live = [...canopy.live].sort();
  const idle = [...canopy.idle].sort();
  const calls = [...pane.log.calls].reverse();
  return (
    <div
      className="grid h-full min-h-0 grid-cols-2 bg-shade/70"
      style={{ "--tone": tones[pane.user.id].strong, "--tone-soft": tones[pane.user.id].soft } as CSSProperties}
    >
      <div className="flex min-h-0 flex-col px-4 py-2">
        <div className="mb-1 text-[11px] font-semibold text-muted">
          {pane.preview?.title ?? "Client query canopy"}
        </div>
        {pane.preview ? (
          <pre className="min-h-0 flex-1 overflow-auto whitespace-pre-wrap rounded-md border border-line bg-card p-3 font-mono text-[11px] leading-relaxed text-ink">
            {pane.preview.text ?? JSON.stringify(pane.preview.value, null, 2) ?? String(pane.preview.value)}
          </pre>
        ) : (
          <div className="min-h-0 overflow-y-auto">
            <div className="grid grid-cols-[52px_minmax(0,1fr)] items-start gap-x-2">
              <span className="pt-0.5 text-[11px] font-medium tabular-nums text-ink">Live {live.length}</span>
              <div className="flex min-h-5 flex-wrap items-center gap-1.5">
                {live.length === 0 ? (
                  <span className="rounded-md border border-line/80 bg-shade px-1.5 py-0.5 text-[11px] text-faint">
                    none
                  </span>
                ) : (
                  live.map((key) => (
                    <span
                      key={`live:${key}`}
                      className="rounded-md border border-line bg-card px-1.5 py-0.5 text-[11px]"
                    >
                      {keyText(key)}
                    </span>
                  ))
                )}
              </div>
            </div>
            <div className="mt-1.5 grid grid-cols-[52px_minmax(0,1fr)] items-start gap-x-2">
              <span className="pt-0.5 text-[11px] font-medium tabular-nums text-muted">Idle {idle.length}</span>
              <div className="flex min-h-5 flex-wrap items-center gap-1.5">
                {idle.length === 0 ? (
                  <span className="rounded-md border border-line/80 bg-shade px-1.5 py-0.5 text-[11px] text-faint">
                    none
                  </span>
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
          </div>
        )}
      </div>
      <div className="flex min-h-0 flex-col border-l border-line px-4 py-2">
        <div className="mb-1 text-[11px] font-semibold text-muted">Adaptor calls</div>
        <div className="min-h-0 flex-1 space-y-1 overflow-y-auto pr-1">
          {calls.length === 0 ? (
            <span className="text-[11px] text-faint">none</span>
          ) : (
            calls.map((call) => {
              const label = callLabel(call.label);
              const title = `${call.tag} ${call.reply ? "reply " : ""}${call.name}${label ? ` · ${label}` : ""}`;
              return (
                <div key={call.seq} className="min-w-0 text-[11px] leading-5">
                  <span
                    className={`mr-1.5 inline-flex rounded border px-1 py-px font-medium align-middle
                      ${
                        call.tag === "remote"
                          ? "border-(--tone)/30 bg-(--tone-soft) text-(--tone)"
                          : "border-line bg-card text-muted"
                      }`}
                  >
                    {call.tag}
                  </span>
                  {call.reply ? (
                    <>
                      {label && (
                        <span className="inline-block max-w-[65%] truncate align-middle font-medium text-ink">
                          {label}
                        </span>
                      )}
                      <span className="mx-1 inline-block align-middle text-faint">↳</span>
                      <span className="inline-block font-medium align-middle text-ink">{call.name}</span>
                    </>
                  ) : (
                    <>
                      <span className="inline-block font-medium align-middle text-ink">{call.name}</span>
                      {label && (
                        <span className="ml-1.5 inline-block max-w-[65%] truncate align-middle font-mono text-faint">
                          {label}
                        </span>
                      )}
                    </>
                  )}
                  <CallValue pane={pane} title={title} value={call.value} />
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
}

const fieldLabels: Record<ClaimField, string> = {
  claimant: "Claimant",
  peril: "Peril",
  city: "City",
  status: "Status",
  adjuster: "Adjuster",
  estimate: "Estimate (CHF)",
  notes: "Notes",
};

function Resolver({ claims }: { claims: ClaimsFeature }) {
  useTilia();
  const resolution = claims.resolution;
  if (!resolution) return null;
  return (
    <div className="absolute inset-0 z-20 flex items-center justify-center bg-ink/20 p-6">
      <div className="flex max-h-full w-full max-w-xl flex-col rounded-md border border-line bg-card shadow-xl">
        <div className="border-b border-line px-4 py-3">
          <div className="text-[14px] font-semibold text-ink">Resolve conflict</div>
          <div className="mt-0.5 font-mono text-[11px] text-muted">{resolution.draft.id}</div>
        </div>
        <div className="grid min-h-0 flex-1 grid-cols-2 gap-3 overflow-y-auto p-4">
          {fields.map((field) => (
            <div key={field} className={field === "notes" ? "col-span-2" : ""}>
              <ResolutionField field={field} conflict={resolution.fields.includes(field)} claims={claims} />
            </div>
          ))}
        </div>
        <div className="flex justify-end gap-2 border-t border-line px-4 py-3">
          <Button kind="quiet" onClick={claims.discardResolution}>
            Discard
          </Button>
          <Button kind="primary" onClick={claims.saveResolution}>
            Save
          </Button>
        </div>
      </div>
    </div>
  );
}

function ResolutionField({
  field,
  conflict,
  claims,
}: {
  field: ClaimField;
  conflict: boolean;
  claims: ClaimsFeature;
}) {
  const resolution = claims.resolution;
  if (!resolution) return null;
  const value = resolution.draft[field];
  const mine = resolution.mine[field];
  const theirs = resolution.theirs[field];
  const mineSelected = value === mine;
  const alternate = mineSelected ? theirs : mine;
  const side = mineSelected ? "theirs" : "mine";
  const change = (next: Claim[ClaimField]) => Object.assign(resolution.draft, { [field]: next });
  return (
    <Field label={fieldLabels[field]}>
      {field === "status" ? (
        <select className={`${inputStyle} capitalize`} value={value as Status} onChange={(e) => change(e.target.value as Status)}>
          {statuses.map((status) => (
            <option key={status} value={status}>
              {status}
            </option>
          ))}
        </select>
      ) : field === "estimate" ? (
        <input
          className={`${inputStyle} font-mono`}
          type="number"
          min={0}
          step={100}
          value={value as number}
          onChange={(e) => change(Number(e.target.value) || 0)}
        />
      ) : field === "notes" ? (
        <textarea
          className={`${inputStyle} min-h-20 resize-y`}
          value={value as string}
          onChange={(e) => change(e.target.value)}
        />
      ) : (
        <input className={inputStyle} value={value as string} onChange={(e) => change(e.target.value)} />
      )}
      {conflict && (
        <button
          type="button"
          className="mt-1 border-0 bg-transparent p-0 text-left text-[11px] font-medium text-(--tone) hover:underline"
          onClick={() => change(alternate)}
        >
          {side}: <span className="font-mono">{String(alternate) || "—"}</span>
        </button>
      )}
    </Field>
  );
}

const List = leaf(function List({ claims }: { claims: ClaimsFeature }) {
  const list = claims.list;
  if (list === "loading") {
    return (
      <div className="flex flex-col gap-2 p-4">
        {[0, 1, 2].map((i) => (
          <div key={i} className="h-11 animate-pulse rounded-md bg-shade" />
        ))}
      </div>
    );
  }
  if (list === "notFound") {
    return <div className="p-6 text-center text-[13px] text-muted">No claims in this view.</div>;
  }
  if (list === "notLocal") {
    return <div className="p-6 text-center text-[13px] text-muted">No saved claims are available offline.</div>;
  }
  if (list.state === "failed") {
    return <div className="p-6 text-center text-[13px] text-warn-fg">Could not load claims: {list.message}</div>;
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
