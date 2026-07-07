// Apply the canonical SQL migrations in infra/sql in filename order.
// Usage: DATABASE_URL=... node scripts/apply-sql.mjs
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import postgres from "postgres";

const here = dirname(fileURLToPath(import.meta.url));
const sqlDir = resolve(here, "../../../../infra/sql");
const url = process.env.DATABASE_URL;
if (!url) {
  console.error("DATABASE_URL is required");
  process.exit(1);
}

const files = readdirSync(sqlDir)
  .filter((f) => f.endsWith(".sql"))
  .sort();

const sql = postgres(url, { max: 1 });
try {
  for (const file of files) {
    const text = readFileSync(join(sqlDir, file), "utf8");
    process.stdout.write(`Applying ${file} ... `);
    await sql.unsafe(text);
    console.log("ok");
  }
  console.log(`\n✓ Applied ${files.length} migration(s).`);
} finally {
  await sql.end();
}
