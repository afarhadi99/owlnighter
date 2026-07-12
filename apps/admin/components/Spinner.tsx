/**
 * Animated SVG spinner — a star orbiting a faint ring — used anywhere the
 * console would otherwise show plain "Loading…" text. Under
 * `prefers-reduced-motion: reduce` the orbit animation is disabled; the dot
 * simply rests at the top of the ring, a static-but-legible loading glyph
 * rather than a blank space.
 */
export function Spinner({
  size = 16,
  className = "",
}: {
  size?: number;
  className?: string;
}) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      role="status"
      aria-label="Loading"
      className={`inline-block align-[-3px] text-current ${className}`}
    >
      <circle
        cx="12"
        cy="12"
        r="9"
        fill="none"
        stroke="currentColor"
        strokeOpacity="0.2"
        strokeWidth="2"
      />
      <g className="origin-center animate-orbit motion-reduce:animate-none">
        <path
          d="M12 3.4 L12.9 5.6 L15.2 5.9 L13.5 7.4 L14 9.6 L12 8.4 L10 9.6 L10.5 7.4 L8.8 5.9 L11.1 5.6 Z"
          fill="currentColor"
        />
      </g>
    </svg>
  );
}
