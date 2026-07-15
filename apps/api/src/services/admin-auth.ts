import { sql, eq } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import type {
  AdminLoginRequest,
  AdminLoginResponse,
  AdminMeResponse,
  AdminSignupRequest,
  AdminSignupResponse,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { badRequest, forbidden, unauthorized } from "../plugins/errors.js";
import { generateSessionToken, hashToken } from "../utils/admin-crypto.js";
import type { AdminPrincipal } from "../types.js";

const SESSION_DAYS = 30;

/** postgres-js's driver returns rows as a plain array; guard the node-postgres
 * `{rows}` shape too so this stays correct if the underlying driver ever changes. */
async function execOne<T>(deps: Deps, query: ReturnType<typeof sql>): Promise<T | undefined> {
  const result = await deps.db.execute(query);
  const rows = Array.isArray(result) ? result : ((result as { rows?: unknown[] }).rows ?? []);
  return rows[0] as T | undefined;
}

async function hashPassword(deps: Deps, password: string): Promise<string> {
  // Explicit bcrypt cost factor: pgcrypto's gen_salt('bf') defaults iter_count to
  // 6 when omitted, well below the ~10-12 considered an adequate minimum today.
  const row = await execOne<{ hash: string }>(deps, sql`select crypt(${password}, gen_salt('bf', 12)) as hash`);
  if (!row) throw new Error("Password hashing failed.");
  return row.hash;
}

/** pgcrypto verify idiom: crypt(candidate, storedHash) re-derives the same hash
 * (using the salt embedded in storedHash) iff candidate is the right password. */
async function verifyPassword(deps: Deps, password: string, storedHash: string): Promise<boolean> {
  const row = await execOne<{ valid: boolean }>(
    deps,
    sql`select (crypt(${password}, ${storedHash}) = ${storedHash}) as valid`,
  );
  return row?.valid ?? false;
}

// A fixed, valid bcrypt hash (its own password is irrelevant — it's never compared
// against real input) so the "no such account" path below runs a comparable-cost
// crypt() call to the "wrong password" path, closing a timing side-channel that
// would otherwise let an attacker enumerate valid emails by response latency.
const DUMMY_HASH = "$2a$12$CwTycUXWue0Thq9StjUM0uJ8i54STe.pxGnwWnKM4nfPjxxfoKGty";

export async function signup(deps: Deps, req: AdminSignupRequest): Promise<AdminSignupResponse> {
  const existing = await deps.db
    .select({ id: schema.adminAccounts.id })
    .from(schema.adminAccounts)
    .where(sql`lower(${schema.adminAccounts.email}) = lower(${req.email})`)
    .limit(1);
  if (existing[0]) throw badRequest("An account with this email already exists or is pending approval.");

  const passwordHash = await hashPassword(deps, req.password);
  await deps.db.insert(schema.adminAccounts).values({
    email: req.email,
    passwordHash,
    status: "pending",
    isAdmin: false,
  });
  return {
    status: "pending",
    message: "Signup received. An existing admin must approve this account before you can log in.",
  };
}

export async function login(deps: Deps, req: AdminLoginRequest): Promise<AdminLoginResponse> {
  const rows = await deps.db
    .select()
    .from(schema.adminAccounts)
    .where(sql`lower(${schema.adminAccounts.email}) = lower(${req.email})`)
    .limit(1);
  const account = rows[0];
  if (!account) {
    await verifyPassword(deps, req.password, DUMMY_HASH); // burn comparable time, ignore result
    throw unauthorized("Invalid email or password.");
  }

  const ok = await verifyPassword(deps, req.password, account.passwordHash);
  if (!ok) throw unauthorized("Invalid email or password.");

  if (account.status === "pending") throw forbidden("This account is awaiting admin approval.");
  if (account.status === "rejected") throw forbidden("This account's access request was rejected.");
  if (!account.isAdmin) throw forbidden("This account does not have admin access.");

  const token = generateSessionToken();
  const expiresAt = new Date(Date.now() + SESSION_DAYS * 24 * 60 * 60 * 1000);
  await deps.db.insert(schema.adminSessions).values({
    adminAccountId: account.id,
    tokenHash: hashToken(token),
    expiresAt,
  });

  return { token, expiresAt: expiresAt.toISOString(), account: { id: account.id, email: account.email } };
}

export async function logout(deps: Deps, token: string): Promise<void> {
  await deps.db.delete(schema.adminSessions).where(eq(schema.adminSessions.tokenHash, hashToken(token)));
}

export function me(admin: AdminPrincipal): AdminMeResponse {
  return { id: admin.id, email: admin.email, isAdmin: admin.isAdmin };
}
