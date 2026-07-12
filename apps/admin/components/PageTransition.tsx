"use client";

import { usePathname } from "next/navigation";
import type { ReactNode } from "react";

/**
 * Shared fade/slide-in wrapper for route content — CSS animation only
 * (tailwind.config.ts: `fade-slide-in`), re-keyed per pathname so it replays
 * on navigation. Disabled under `prefers-reduced-motion: reduce`.
 */
export function PageTransition({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  return (
    <div key={pathname} className="animate-fade-slide-in motion-reduce:animate-none">
      {children}
    </div>
  );
}
