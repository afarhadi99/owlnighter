import type { ReactNode } from "react";

type Tone = "neutral" | "good" | "warn" | "bad";

const toneClass: Record<Tone, string> = {
  neutral: "text-slate-100",
  good: "text-good",
  warn: "text-warn",
  bad: "text-bad",
};

export function StatTile({
  label,
  value,
  sub,
  tone = "neutral",
  children,
}: {
  label: string;
  value: ReactNode;
  sub?: ReactNode;
  tone?: Tone;
  children?: ReactNode;
}) {
  return (
    <div className="rounded-md border border-line bg-ink-800 p-4">
      <div className="text-[11px] uppercase tracking-widest text-muted">
        {label}
      </div>
      <div className={`mt-1 font-mono text-2xl font-semibold ${toneClass[tone]}`}>
        {value}
      </div>
      {sub ? <div className="mt-1 text-xs text-muted">{sub}</div> : null}
      {children ? <div className="mt-3">{children}</div> : null}
    </div>
  );
}
