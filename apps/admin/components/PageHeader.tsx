import type { ReactNode } from "react";

export function PageHeader({
  title,
  subtitle,
  right,
}: {
  title: string;
  subtitle?: ReactNode;
  right?: ReactNode;
}) {
  return (
    <div className="mb-6 flex items-start justify-between gap-4 border-b border-line pb-4">
      <div>
        <h1 className="font-mono text-lg font-semibold text-slate-100">
          {title}
        </h1>
        {subtitle ? (
          <p className="mt-1 max-w-2xl text-sm text-muted">{subtitle}</p>
        ) : null}
      </div>
      {right ? <div className="shrink-0">{right}</div> : null}
    </div>
  );
}

/** Consistent "not yet wired" callout so mock surfaces are honest. */
export function TodoBanner({ children }: { children: ReactNode }) {
  return (
    <div className="mb-4 rounded-md border border-warn/40 bg-warn/10 px-3 py-2 text-xs text-warn">
      TODO wire to API — {children}
    </div>
  );
}
