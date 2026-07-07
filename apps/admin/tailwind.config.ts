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
    },
  },
  plugins: [],
};

export default config;
