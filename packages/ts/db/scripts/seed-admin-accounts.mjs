// Idempotent upsert of the 3 pre-approved admin-panel accounts.
// Usage: DATABASE_URL=... SEED_ADMIN_PASSWORD_RCOHEN=... SEED_ADMIN_PASSWORD_NKUKAJ=... SEED_ADMIN_PASSWORD_AFARHADI=... node scripts/seed-admin-accounts.mjs
import postgres from "postgres";

const url = process.env.DATABASE_URL;
if (!url) {
  console.error("DATABASE_URL is required");
  process.exit(1);
}

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    console.error(`${name} is required (set it in your local .env, never commit real values)`);
    process.exit(1);
  }
  if (value === "changeme") {
    console.error(
      `${name} is still set to the .env.example placeholder "changeme" — replace it with a real password before seeding admin accounts`,
    );
    process.exit(1);
  }
  return value;
}

const ACCOUNTS = [
  { email: "rcohen@mytsi.org", password: requireEnv("SEED_ADMIN_PASSWORD_RCOHEN") },
  { email: "nkukaj@mytsi.org", password: requireEnv("SEED_ADMIN_PASSWORD_NKUKAJ") },
  { email: "afarhadi@mytsi.org", password: requireEnv("SEED_ADMIN_PASSWORD_AFARHADI") },
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
