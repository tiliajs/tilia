import type { ReactNode } from "react";
import type { Status } from "../app/claim";

export const tones: Record<string, { strong: string; soft: string }> = {
  ana: { strong: "var(--color-ana)", soft: "var(--color-ana-soft)" },
  ben: { strong: "var(--color-ben)", soft: "var(--color-ben-soft)" },
};

export function Button({
  children,
  onClick,
  kind = "ghost",
  disabled,
  title,
}: {
  children: ReactNode;
  onClick: () => void;
  kind?: "primary" | "ghost" | "quiet";
  disabled?: boolean;
  title?: string;
}) {
  const styles = {
    primary: "bg-ink text-paper hover:bg-ink/85 border border-ink",
    ghost: "bg-card text-ink border border-line hover:border-faint",
    quiet: "text-muted hover:text-ink border border-transparent hover:border-line",
  };
  return (
    <button
      type="button"
      title={title}
      disabled={disabled}
      onClick={onClick}
      className={`inline-flex items-center gap-1.5 rounded-md px-2.5 py-1 text-[13px] font-medium
        transition-colors duration-150 disabled:opacity-40 disabled:pointer-events-none ${styles[kind]}`}
    >
      {children}
    </button>
  );
}

const statusStyles: Record<Status, string> = {
  new: "bg-new-bg text-new-fg",
  assigned: "bg-assigned-bg text-assigned-fg",
  inspected: "bg-inspected-bg text-inspected-fg",
  closed: "bg-closed-bg text-closed-fg",
};

export function StatusBadge({ status }: { status: Status }) {
  return (
    <span className={`rounded-md px-1.5 py-0.5 text-[11px] font-medium capitalize ${statusStyles[status]}`}>
      {status}
    </span>
  );
}

export function Switch({ on, change, label }: { on: boolean; change: (on: boolean) => void; label: string }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      aria-label={label}
      onClick={() => change(!on)}
      className={`relative h-5 w-9 rounded-full transition-colors duration-150
        ${on ? "bg-(--tone)" : "bg-faint/60"}`}
    >
      <span
        className={`absolute top-0.5 h-4 w-4 rounded-full bg-card shadow-sm transition-all duration-150
          ${on ? "left-4.5" : "left-0.5"}`}
      />
    </button>
  );
}

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="flex flex-col gap-1 text-[12px] font-medium text-muted">
      {label}
      {children}
    </label>
  );
}

export const inputStyle = `rounded-md border border-line bg-card px-2.5 py-1.5 text-[13px] font-normal text-ink
  outline-none transition-colors duration-150 focus:border-(--tone) placeholder:text-faint`;

export function money(amount: number): string {
  return `CHF ${amount.toLocaleString("de-CH")}`;
}
