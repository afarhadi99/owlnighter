import type { Config } from "drizzle-kit";

/**
 * Optional: for `drizzle-kit studio` / introspection during development.
 * Runtime migrations are the hand-written SQL in infra/sql (see scripts/apply-sql.mjs).
 */
export default {
  schema: "./src/schema.ts",
  dialect: "postgresql",
  out: "./drizzle",
  dbCredentials: {
    url: process.env.DATABASE_URL ?? "",
  },
} satisfies Config;
