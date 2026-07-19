import { and, desc, eq, gt, isNull, or, sql } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import type {
  ActivateAccountRequest,
  ActivateAccountResponse,
  AdminCreateReferralCodeRequest,
  AdminListReferralCodesResponse,
  AdminReferralCode,
  AdminUpdateReferralCodeRequest,
  AuthStatusResponse,
  ValidateReferralCodeRequest,
  ValidateReferralCodeResponse,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import type { AdminPrincipal, AuthUser } from "../types.js";
import { badRequest, notFound } from "../plugins/errors.js";

// Unambiguous alphabet — no 0/O/1/I/L — so a code read aloud or handwritten
// can't be misheard/misread into a different valid code.
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

function randomCode(): string {
  let out = "";
  for (let i = 0; i < 8; i++) out += CODE_ALPHABET[Math.floor(Math.random() * CODE_ALPHABET.length)];
  return out;
}

function toDto(row: typeof schema.referralCodes.$inferSelect): AdminReferralCode {
  return {
    id: row.id,
    code: row.code,
    label: row.label,
    maxUses: row.maxUses,
    useCount: row.useCount,
    isActive: row.isActive,
    expiresAt: row.expiresAt ? row.expiresAt.toISOString() : null,
    createdAt: row.createdAt.toISOString(),
  };
}

async function findByCode(deps: Deps, code: string) {
  const rows = await deps.db
    .select()
    .from(schema.referralCodes)
    .where(sql`lower(${schema.referralCodes.code}) = lower(${code})`)
    .limit(1);
  return rows[0];
}

/** Read-only check used by the signup screen before the user submits — does
 * NOT consume a use. The atomic consume happens in `activateAccount`, so a
 * code that passes this check can still fail there under a race (e.g. the
 * last two uses of a max_uses=1 code redeemed simultaneously). */
export async function validateReferralCode(
  deps: Deps,
  req: ValidateReferralCodeRequest,
): Promise<ValidateReferralCodeResponse> {
  const row = await findByCode(deps, req.code);
  if (!row) return { valid: false, reason: "Code not found." };
  if (!row.isActive) return { valid: false, reason: "This code is no longer active." };
  if (row.expiresAt && row.expiresAt.getTime() <= Date.now()) return { valid: false, reason: "This code has expired." };
  if (row.maxUses !== null && row.useCount >= row.maxUses) {
    return { valid: false, reason: "This code has reached its usage limit." };
  }
  return { valid: true };
}

/** Whether the caller's Supabase session has a `profiles` row yet. A
 * Supabase-authenticated user with no profile has signed up/in but not yet
 * redeemed a referral code — the app should show the activation screen. */
export async function getAuthStatus(deps: Deps, user: AuthUser): Promise<AuthStatusResponse> {
  const rows = await deps.db.select({ id: schema.profiles.id }).from(schema.profiles).where(eq(schema.profiles.id, user.id)).limit(1);
  return { activated: Boolean(rows[0]) };
}

/** Redeem a code and create the caller's profile, atomically. Idempotent: a
 * caller who already has a profile just gets it back unchanged (covers a
 * retried request or a returning user re-hitting this by mistake). */
export async function activateAccount(
  deps: Deps,
  user: AuthUser,
  req: ActivateAccountRequest,
): Promise<ActivateAccountResponse> {
  const existing = await deps.db
    .select({ id: schema.profiles.id, displayName: schema.profiles.displayName, isAdmin: schema.profiles.isAdmin })
    .from(schema.profiles)
    .where(eq(schema.profiles.id, user.id))
    .limit(1);
  if (existing[0]) return existing[0];

  return deps.db.transaction(async (tx) => {
    // Atomic check-and-consume: the WHERE clause re-validates active/expiry/
    // usage-limit at the moment of the UPDATE, closing the race window a
    // separate validate-then-consume pair would leave open.
    const consumed = await tx
      .update(schema.referralCodes)
      .set({ useCount: sql`${schema.referralCodes.useCount} + 1` })
      .where(
        and(
          sql`lower(${schema.referralCodes.code}) = lower(${req.referralCode})`,
          eq(schema.referralCodes.isActive, true),
          or(isNull(schema.referralCodes.expiresAt), gt(schema.referralCodes.expiresAt, new Date())),
          or(isNull(schema.referralCodes.maxUses), sql`${schema.referralCodes.useCount} < ${schema.referralCodes.maxUses}`),
        ),
      )
      .returning({ id: schema.referralCodes.id });
    const code = consumed[0];
    if (!code) throw badRequest("Invalid, inactive, expired, or fully-redeemed referral code.");

    await tx.insert(schema.profiles).values({ id: user.id, displayName: req.displayName ?? null });
    await tx.insert(schema.referralRedemptions).values({ referralCodeId: code.id, userId: user.id });

    return { id: user.id, displayName: req.displayName ?? null, isAdmin: false };
  });
}

export async function adminListReferralCodes(deps: Deps): Promise<AdminListReferralCodesResponse> {
  const rows = await deps.db.select().from(schema.referralCodes).orderBy(desc(schema.referralCodes.createdAt));
  return { codes: rows.map(toDto) };
}

export async function adminCreateReferralCode(
  deps: Deps,
  admin: AdminPrincipal,
  req: AdminCreateReferralCodeRequest,
): Promise<AdminReferralCode> {
  const expiresAt = req.expiresAt ? new Date(req.expiresAt) : null;

  if (req.code) {
    if (await findByCode(deps, req.code)) throw badRequest("A referral code with this value already exists.");
    const rows = await deps.db
      .insert(schema.referralCodes)
      .values({ code: req.code, label: req.label ?? null, maxUses: req.maxUses ?? null, expiresAt, createdBy: admin.id })
      .returning();
    return toDto(rows[0]!);
  }

  // Auto-generated: retry on the astronomically unlikely collision rather
  // than surfacing it to the admin as an error.
  for (let attempt = 0; attempt < 5; attempt++) {
    const candidate = randomCode();
    if (await findByCode(deps, candidate)) continue;
    const rows = await deps.db
      .insert(schema.referralCodes)
      .values({ code: candidate, label: req.label ?? null, maxUses: req.maxUses ?? null, expiresAt, createdBy: admin.id })
      .returning();
    return toDto(rows[0]!);
  }
  throw badRequest("Could not generate a unique referral code — try again.");
}

export async function adminUpdateReferralCode(
  deps: Deps,
  id: string,
  req: AdminUpdateReferralCodeRequest,
): Promise<AdminReferralCode> {
  const existing = await deps.db.select({ id: schema.referralCodes.id }).from(schema.referralCodes).where(eq(schema.referralCodes.id, id)).limit(1);
  if (!existing[0]) throw notFound("Referral code not found.");

  const patch: Partial<typeof schema.referralCodes.$inferInsert> = {};
  if (req.label !== undefined) patch.label = req.label;
  if (req.isActive !== undefined) patch.isActive = req.isActive;
  if (req.maxUses !== undefined) patch.maxUses = req.maxUses;
  if (req.expiresAt !== undefined) patch.expiresAt = req.expiresAt ? new Date(req.expiresAt) : null;

  const rows = await deps.db.update(schema.referralCodes).set(patch).where(eq(schema.referralCodes.id, id)).returning();
  return toDto(rows[0]!);
}
