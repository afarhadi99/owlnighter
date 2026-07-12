"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { OwlLogo } from "@/components/OwlLogo";
import { SFX_MUTE_EVENT, isMuted, setMuted } from "@/lib/sfx";

// Modules mirror the blueprint's "Admin dashboard feature set" table.
const NAV: { href: string; label: string; hint: string }[] = [
  { href: "/", label: "Overview", hint: "health tiles" },
  { href: "/books", label: "Books & Reconciliation", hint: "candidate merges" },
  { href: "/grounding", label: "Grounding Review", hint: "citations · facts" },
  { href: "/plans", label: "Plan QA", hint: "path steps" },
  { href: "/quiz", label: "Quiz QA", hint: "answer keys · invalidation" },
  { href: "/tts", label: "TTS QA", hint: "cache · voices" },
  { href: "/notifications", label: "Notifications", hint: "templates · tokens" },
  { href: "/support", label: "User Support", hint: "streak · plan reset" },
  { href: "/model-ops", label: "Model Operations", hint: "routing · fallback" },
];

export function Sidebar() {
  const pathname = usePathname();
  const [muted, setMutedState] = useState(false);

  useEffect(() => {
    setMutedState(isMuted());
    const onChange = (e: Event) => setMutedState((e as CustomEvent<boolean>).detail);
    window.addEventListener(SFX_MUTE_EVENT, onChange);
    return () => window.removeEventListener(SFX_MUTE_EVENT, onChange);
  }, []);

  function toggleMuted() {
    const next = !muted;
    setMuted(next);
    setMutedState(next);
  }

  return (
    <aside className="flex w-60 shrink-0 flex-col border-r border-line bg-ink-800">
      <div className="flex items-center gap-2.5 border-b border-line px-4 py-4">
        <OwlLogo size={30} />
        <div>
          <div className="font-mono text-sm font-semibold tracking-tight text-accent">
            owlnighter
          </div>
          <div className="text-[11px] uppercase tracking-widest text-muted">
            grounding console
          </div>
        </div>
      </div>

      <nav className="flex-1 overflow-y-auto py-2">
        {NAV.map((item) => {
          const active =
            item.href === "/"
              ? pathname === "/"
              : pathname.startsWith(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={[
                "block border-l-2 px-4 py-2 text-sm transition-colors",
                active
                  ? "border-accent bg-ink-700 text-slate-100"
                  : "border-transparent text-slate-300 hover:bg-ink-700 hover:text-slate-100",
              ].join(" ")}
            >
              <div>{item.label}</div>
              <div className="text-[11px] text-muted">{item.hint}</div>
            </Link>
          );
        })}
      </nav>

      <div className="border-t border-line px-4 py-3 text-[11px] text-muted">
        <div className="flex items-center justify-between gap-2">
          <span className="truncate">
            env: {process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8787"}
          </span>
          <button
            type="button"
            onClick={toggleMuted}
            aria-pressed={muted}
            title={muted ? "Sound off — click to enable chimes" : "Sound on — click to mute"}
            className="shrink-0 rounded border border-line px-1.5 py-0.5 text-[11px] text-muted transition-colors hover:border-accent hover:text-accent"
          >
            {muted ? "🔇" : "🔔"}
          </button>
        </div>
      </div>
    </aside>
  );
}
