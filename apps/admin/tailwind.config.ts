import type { Config } from "tailwindcss";

// Dense, dark ops console. Data-heavy surfaces lean on the mono stack.
const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: {
          900: "#0a0c10",
          800: "#0f131a",
          700: "#161b24",
          600: "#1e2530",
          500: "#2a3340",
        },
        line: "#2a3340",
        muted: "#8b97a8",
        accent: "#5e8bff",
        good: "#3ecf8e",
        warn: "#f5b544",
        bad: "#f2555a",
      },
      fontFamily: {
        mono: ["ui-monospace", "SFMono-Regular", "Menlo", "Consolas", "monospace"],
        sans: ["ui-sans-serif", "system-ui", "Segoe UI", "sans-serif"],
      },
      keyframes: {
        owlBreathe: {
          "0%, 100%": { transform: "scale(1)" },
          "50%": { transform: "scale(1.035)" },
        },
        owlBlink: {
          "0%, 92%, 100%": { transform: "scaleY(0)" },
          "95%": { transform: "scaleY(1)" },
        },
        twinkle: {
          "0%, 100%": { opacity: "0.25" },
          "50%": { opacity: "1" },
        },
        fadeSlideIn: {
          "0%": { opacity: "0", transform: "translateY(6px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        orbit: {
          "0%": { transform: "rotate(0deg)" },
          "100%": { transform: "rotate(360deg)" },
        },
      },
      animation: {
        "owl-breathe": "owlBreathe 4s ease-in-out infinite",
        "owl-blink": "owlBlink 4.2s ease-in-out infinite",
        twinkle: "twinkle 2.6s ease-in-out infinite",
        "fade-slide-in": "fadeSlideIn 0.35s ease-out both",
        orbit: "orbit 1s linear infinite",
      },
    },
  },
  plugins: [],
};

export default config;
