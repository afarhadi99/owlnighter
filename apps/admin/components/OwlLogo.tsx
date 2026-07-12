"use client";

import { useId } from "react";

/**
 * Hand-crafted inline SVG owl mark — the console's mascot.
 *
 * Idle motion: a slow "breathing" scale on the whole mark plus a periodic
 * blink on the eyelid circles (~every 4s). Both are pure CSS keyframe
 * animations (see tailwind.config.ts: owl-breathe / owl-blink) and both are
 * disabled under `prefers-reduced-motion: reduce` — the fallback is simply
 * the owl at rest with eyes open, never blank.
 */
export function OwlLogo({ size = 32, className = "" }: { size?: number; className?: string }) {
  const uid = useId().replace(/[^a-zA-Z0-9]/g, "");
  const gradId = `owl-body-${uid}`;

  return (
    <svg
      viewBox="0 0 64 64"
      width={size}
      height={size}
      role="img"
      aria-label="owlnighter"
      className={`origin-center animate-owl-breathe motion-reduce:animate-none ${className}`}
    >
      <defs>
        <radialGradient id={gradId} cx="50%" cy="35%" r="70%">
          <stop offset="0%" stopColor="#2a3340" />
          <stop offset="100%" stopColor="#161b24" />
        </radialGradient>
      </defs>

      {/* wings */}
      <path
        d="M8 40 C6 28 12 18 20 14 C16 24 16 34 20 44 C14 44 10 43 8 40 Z"
        fill="#1e2530"
      />
      <path
        d="M56 40 C58 28 52 18 44 14 C48 24 48 34 44 44 C50 44 54 43 56 40 Z"
        fill="#1e2530"
      />

      {/* body */}
      <ellipse cx="32" cy="36" rx="19" ry="21" fill={`url(#${gradId})`} stroke="#2a3340" strokeWidth="1" />

      {/* ear tufts */}
      <path d="M18 16 L22 8 L26 17 Z" fill="#161b24" />
      <path d="M46 16 L42 8 L38 17 Z" fill="#161b24" />

      {/* face disc */}
      <circle cx="32" cy="32" r="16" fill="#0f131a" />

      {/* eyes */}
      <circle cx="24" cy="31" r="7" fill="#e8ecf3" />
      <circle cx="40" cy="31" r="7" fill="#e8ecf3" />
      <circle cx="24" cy="31" r="3.4" fill="#5e8bff" />
      <circle cx="40" cy="31" r="3.4" fill="#5e8bff" />
      <circle cx="24" cy="31" r="1.1" fill="#0a0c10" />
      <circle cx="40" cy="31" r="1.1" fill="#0a0c10" />

      {/* eyelids — scaleY(0) is "open" (invisible), scaleY(1) briefly covers the eye */}
      <circle
        cx="24"
        cy="31"
        r="7.2"
        fill="#0f131a"
        className="origin-center animate-owl-blink motion-reduce:animate-none motion-reduce:[transform:scaleY(0)]"
        style={{ transformOrigin: "24px 31px" }}
      />
      <circle
        cx="40"
        cy="31"
        r="7.2"
        fill="#0f131a"
        className="origin-center animate-owl-blink motion-reduce:animate-none motion-reduce:[transform:scaleY(0)]"
        style={{ transformOrigin: "40px 31px" }}
      />

      {/* beak */}
      <path d="M32 37 L28 43 L36 43 Z" fill="#f5b544" />
    </svg>
  );
}
