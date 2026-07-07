import type { ReactNode } from "react";

type Tone = "neutral" | "good" | "warn" | "bad" | "info";

const toneClass: Record<Tone, string> = {
  neutral: "bg-ink-600 text-slate-300",
  good: "bg-good/15 text-good",
  warn: "bg-warn/15 text-warn",
  bad: "bg-bad/15 text-bad",
  info: "bg-accent/15 text-accent",
};

export function Badge({
  children,
  tone = "neutral",
}: {
  children: ReactNode;
  tone?: Tone;
}) {
  return (
    <span
      className={`inline-block rounded px-1.5 py-0.5 font-mono text-[11px] ${toneClass[tone]}`}
    >
      {children}
    </span>
  );
}

/** Map a confidence score to a tone using the blueprint thresholds. */
export function confidenceTone(c: number): Tone {
  if (c >= 0.85) return "good";
  if (c >= 0.6) return "warn";
  return "bad";
}

/** Map a QuizMode to a tone (grounded=trusted, fallback=weak). */
export function quizModeTone(mode: string): Tone {
  switch (mode) {
    case "grounded":
      return "good";
    case "user_text":
      return "info";
    case "preview":
      return "warn";
    default:
      return "bad";
  }
}
