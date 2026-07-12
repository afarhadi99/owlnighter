"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";

type Tone = "neutral" | "good" | "warn" | "bad";

const toneClass: Record<Tone, string> = {
  neutral: "text-slate-100",
  good: "text-good",
  warn: "text-warn",
  bad: "text-bad",
};

const toneStroke: Record<Tone, string> = {
  neutral: "#8b97a8",
  good: "#3ecf8e",
  warn: "#f5b544",
  bad: "#f2555a",
};

// Decorative fill fraction used when a value isn't a plain percentage — the
// arc is a flourish, not a literal chart, so a per-tone baseline reads fine.
const toneFraction: Record<Tone, number> = {
  neutral: 0.6,
  good: 0.78,
  warn: 0.5,
  bad: 0.32,
};

function usePrefersReducedMotion(): boolean {
  const [reduced, setReduced] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    setReduced(mq.matches);
    const onChange = (e: MediaQueryListEvent) => setReduced(e.matches);
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, []);
  return reduced;
}

type ParsedValue = { prefix: string; number: number; suffix: string; decimals: number; hadComma: boolean };

/** "83%" -> {prefix:"", number:83, suffix:"%"}; "1,204" -> number:1204; "—" -> null (not animatable). */
function parseValue(value: ReactNode): ParsedValue | null {
  if (typeof value !== "string" && typeof value !== "number") return null;
  const str = String(value);
  const match = str.match(/^([^\d-]*)(-?[\d,]+(?:\.\d+)?)(.*)$/);
  if (!match) return null;
  const [, prefix, numStr, suffix] = match;
  const cleaned = numStr.replace(/,/g, "");
  const number = Number(cleaned);
  if (Number.isNaN(number)) return null;
  const decimals = cleaned.includes(".") ? cleaned.split(".")[1].length : 0;
  return { prefix, number, suffix, decimals, hadComma: numStr.includes(",") };
}

function formatNumber(n: number, parsed: ParsedValue): string {
  const fixed = n.toFixed(parsed.decimals);
  if (!parsed.hadComma) return fixed;
  return Number(fixed).toLocaleString(undefined, {
    minimumFractionDigits: parsed.decimals,
    maximumFractionDigits: parsed.decimals,
  });
}

function easeOutCubic(t: number): number {
  return 1 - Math.pow(1 - t, 3);
}

/** Animated count-up on mount; jumps straight to the final value under reduced motion. */
function CountUp({ value, className }: { value: ReactNode; className?: string }) {
  const parsed = parseValue(value);
  const reducedMotion = usePrefersReducedMotion();
  const [display, setDisplay] = useState<number | null>(parsed ? (reducedMotion ? parsed.number : 0) : null);
  const frame = useRef<number | null>(null);

  useEffect(() => {
    if (!parsed) return;
    if (reducedMotion) {
      setDisplay(parsed.number);
      return;
    }
    const duration = 700;
    const start = performance.now();
    const target = parsed.number;

    function tick(now: number) {
      const t = Math.min(1, (now - start) / duration);
      setDisplay(target * easeOutCubic(t));
      if (t < 1) frame.current = requestAnimationFrame(tick);
    }
    frame.current = requestAnimationFrame(tick);
    return () => {
      if (frame.current !== null) cancelAnimationFrame(frame.current);
    };
    // Re-run only when the underlying number or motion preference changes.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [parsed?.number, reducedMotion]);

  if (!parsed) return <span className={className}>{value}</span>;

  return (
    <span className={className}>
      {parsed.prefix}
      {formatNumber(display ?? parsed.number, parsed)}
      {parsed.suffix}
    </span>
  );
}

/** Tiny inline SVG progress-arc flourish, drawn in on mount. */
function Flourish({ tone, fraction }: { tone: Tone; fraction: number }) {
  const reducedMotion = usePrefersReducedMotion();
  const [progress, setProgress] = useState(reducedMotion ? fraction : 0);
  const raf = useRef<number | null>(null);
  const r = 14;
  const circumference = 2 * Math.PI * r;

  useEffect(() => {
    if (reducedMotion) {
      setProgress(fraction);
      return;
    }
    const start = performance.now();
    const duration = 800;

    function tick(now: number) {
      const t = Math.min(1, (now - start) / duration);
      setProgress(fraction * easeOutCubic(t));
      if (t < 1) raf.current = requestAnimationFrame(tick);
    }
    raf.current = requestAnimationFrame(tick);
    return () => {
      if (raf.current !== null) cancelAnimationFrame(raf.current);
    };
  }, [fraction, reducedMotion]);

  const dash = circumference * Math.max(0, Math.min(1, progress));

  return (
    <svg width="34" height="34" viewBox="0 0 34 34" className="shrink-0" aria-hidden="true">
      <circle cx="17" cy="17" r={r} fill="none" stroke="#1e2530" strokeWidth="3" />
      <circle
        cx="17"
        cy="17"
        r={r}
        fill="none"
        stroke={toneStroke[tone]}
        strokeWidth="3"
        strokeLinecap="round"
        strokeDasharray={`${dash} ${circumference}`}
        transform="rotate(-90 17 17)"
      />
    </svg>
  );
}

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
  const parsed = parseValue(value);
  const fraction =
    parsed && parsed.suffix.trim().startsWith("%")
      ? Math.max(0, Math.min(1, parsed.number / 100))
      : toneFraction[tone];

  return (
    <div
      className="group rounded-md border border-line bg-ink-800 p-4 transition-transform motion-safe:duration-200 hover:border-line/70 hover:shadow-[0_10px_28px_-12px_rgba(0,0,0,0.55)] motion-safe:hover:-translate-y-0.5"
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="text-[11px] uppercase tracking-widest text-muted">{label}</div>
          <div className={`mt-1 font-mono text-2xl font-semibold ${toneClass[tone]}`}>
            <CountUp value={value} />
          </div>
          {sub ? <div className="mt-1 text-xs text-muted">{sub}</div> : null}
        </div>
        <Flourish tone={tone} fraction={fraction} />
      </div>
      {children ? <div className="mt-3">{children}</div> : null}
    </div>
  );
}
