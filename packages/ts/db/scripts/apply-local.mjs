// DEV ONLY — bring a plain Postgres up to the app schema for local API work.
// Applies, in order: the dev auth shim, the canonical infra/sql migrations, then
// the dev seed. Against a real Supabase DB use apply-sql.mjs instead (no shim).
//
// Usage: DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:55432/postgres \
//        node scripts/apply-local.mjs
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import postgres from "postgres";

const here = dirname(fileURLToPath(import.meta.url));
const sqlDir = resolve(here, "../../../../infra/sql");
const devDir = join(sqlDir, "dev");

const url = process.env.DATABASE_URL;
if (!url) {
  console.error("DATABASE_URL is required");
  process.exit(1);
}

const files = [
  join(devDir, "0000_auth_shim.sql"),
  ...readdirSync(sqlDir)
    .filter((f) => f.endsWith(".sql"))
    .sort()
    .map((f) => join(sqlDir, f)),
  join(devDir, "0001_seed_dev.sql"),
];

const sql = postgres(url, { max: 1 });
try {
  for (const file of files) {
    process.stdout.write(`Applying ${file.replace(sqlDir, "infra/sql")} ... `);
    await sql.unsafe(readFileSync(file, "utf8"));
    console.log("ok");
  }
  console.log(`\n✓ Local dev DB ready (${files.length} files applied).`);
} finally {
  await sql.end();
}
