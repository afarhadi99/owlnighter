// Idempotent upsert of the 3 pre-approved admin-panel accounts.
// Usage: DATABASE_URL=... node scripts/seed-admin-accounts.mjs
import postgres from "postgres";

const url = process.env.DATABASE_URL;
if (!url) {
  console.error("DATABASE_URL is required");
  process.exit(1);
}

const ACCOUNTS = [
  { email: "rcohen@mytsi.org", password: "REDACTED_PASSWORD" },
  { email: "nkukaj@mytsi.org", password: "REDACTED_PASSWORD" },
  { email: "afarhadi@mytsi.org", password: "REDACTED_PASSWORD" },
];

const sql = postgres(url, { max: 1 });
try {
  for (const { email, password } of ACCOUNTS) {
    process.stdout.write(`Seeding ${email} ... `);
    await sql`
      insert into admin_accounts (email, password_hash, status, is_admin)
      values (${email}, crypt(${password}, gen_salt('bf')), 'approved', true)
      on conflict (lower(email)) do update
        set password_hash = excluded.password_hash,
            status = 'approved',
            is_admin = true,
            updated_at = now()
    `;
    console.log("ok");
  }
  console.log(`\n✓ Seeded ${ACCOUNTS.length} admin account(s).`);
} finally {
  await sql.end();
}
