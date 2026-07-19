// Scratch helper: run one raw SQL query against DATABASE_URL and print rows.
// Usage: node --env-file=.env packages/ts/db/scripts/query.mjs "select ..."
import postgres from "postgres";

const text = process.argv[2];
if (!text) {
  console.error("Usage: node scripts/query.mjs <sql>");
  process.exit(1);
}
const sql = postgres(process.env.DATABASE_URL, { max: 1 });
try {
  console.log(await sql.unsafe(text));
} finally {
  await sql.end();
}
