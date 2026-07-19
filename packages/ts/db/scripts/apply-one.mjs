// Scratch helper: apply a single migration file by path (used when the full
// apply-sql.mjs re-run would fail on already-applied, non-idempotent DDL like
// CREATE POLICY). Usage: node scripts/apply-one.mjs <path-to-sql-file>
import { readFileSync } from "node:fs";
import postgres from "postgres";

const file = process.argv[2];
if (!file) {
  console.error("Usage: node scripts/apply-one.mjs <path-to-sql-file>");
  process.exit(1);
}
const url = process.env.DATABASE_URL;
if (!url) {
  console.error("DATABASE_URL is required");
  process.exit(1);
}

const sql = postgres(url, { max: 1 });
try {
  await sql.unsafe(readFileSync(file, "utf8"));
  console.log(`Applied ${file} ok`);
} finally {
  await sql.end();
}
