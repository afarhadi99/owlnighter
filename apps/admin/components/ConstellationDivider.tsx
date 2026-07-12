/**
 * Decorative SVG section divider: a faint constellation line strung between
 * twinkling stars. Pure CSS keyframe opacity animation per star
 * (tailwind.config.ts: `twinkle`), staggered via inline `animationDelay`.
 * Disabled under `prefers-reduced-motion: reduce` — stars stay lit, never
 * blank.
 */
export function ConstellationDivider({ className = "" }: { className?: string }) {
  const stars = [
    { x: 12, y: 18, r: 1.6, delay: "0s" },
    { x: 74, y: 8, r: 1.2, delay: "0.4s" },
    { x: 140, y: 22, r: 2, delay: "0.9s" },
    { x: 210, y: 6, r: 1.3, delay: "1.3s" },
    { x: 280, y: 18, r: 1.7, delay: "1.8s" },
    { x: 350, y: 10, r: 1.2, delay: "2.2s" },
    { x: 420, y: 20, r: 1.8, delay: "0.6s" },
    { x: 490, y: 8, r: 1.3, delay: "1.5s" },
    { x: 560, y: 18, r: 1.6, delay: "2.5s" },
  ];

  return (
    <svg
      viewBox="0 0 580 28"
      preserveAspectRatio="none"
      className={`h-6 w-full ${className}`}
      aria-hidden="true"
    >
      <polyline
        points={stars.map((s) => `${s.x},${s.y}`).join(" ")}
        fill="none"
        stroke="#2a3340"
        strokeWidth="1"
      />
      {stars.map((s, i) => (
        <circle
          key={i}
          cx={s.x}
          cy={s.y}
          r={s.r}
          fill="#5e8bff"
          className="animate-twinkle motion-reduce:animate-none"
          style={{ animationDelay: s.delay }}
        />
      ))}
    </svg>
  );
}
