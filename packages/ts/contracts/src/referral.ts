import { z } from "zod";
import { IsoDateTime, Uuid } from "./common.js";

/**
 * Referral codes gate account activation: every new profile — whether the
 * underlying auth.users row came from email/password signup or Google OAuth —
 * redeems exactly one admin-issued code before a `profiles` row is created.
 * See apps/api/src/services/referral.ts.
 */

// ---- POST /v1/auth/validate-referral-code ----
export const ValidateReferralCodeRequest = z.object({ code: z.string().min(1).max(64) });
export type ValidateReferralCodeRequest = z.infer<typeof ValidateReferralCodeRequest>;

export const ValidateReferralCodeResponse = z.object({
  valid: z.boolean(),
  reason: z.string().optional(),
});
export type ValidateReferralCodeResponse = z.infer<typeof ValidateReferralCodeResponse>;

// ---- GET /v1/auth/status ----
export const AuthStatusResponse = z.object({ activated: z.boolean() });
export type AuthStatusResponse = z.infer<typeof AuthStatusResponse>;

// ---- POST /v1/auth/activate ----
export const ActivateAccountRequest = z.object({
  referralCode: z.string().min(1).max(64),
  displayName: z.string().min(1).max(120).optional(),
});
export type ActivateAccountRequest = z.infer<typeof ActivateAccountRequest>;

export const ActivateAccountResponse = z.object({
  id: Uuid,
  displayName: z.string().nullable(),
  isAdmin: z.boolean(),
});
export type ActivateAccountResponse = z.infer<typeof ActivateAccountResponse>;

// ---- Admin referral code management ----
export const AdminReferralCode = z.object({
  id: Uuid,
  code: z.string(),
  label: z.string().nullable(),
  maxUses: z.number().int().nullable(),
  useCount: z.number().int(),
  isActive: z.boolean(),
  expiresAt: IsoDateTime.nullable(),
  createdAt: IsoDateTime,
});
export type AdminReferralCode = z.infer<typeof AdminReferralCode>;

// ---- GET /v1/admin/referral-codes ----
export const AdminListReferralCodesResponse = z.object({ codes: z.array(AdminReferralCode) });
export type AdminListReferralCodesResponse = z.infer<typeof AdminListReferralCodesResponse>;

// ---- POST /v1/admin/referral-codes ----
export const AdminCreateReferralCodeRequest = z.object({
  code: z
    .string()
    .trim()
    .min(4)
    .max(64)
    .regex(/^[A-Za-z0-9-]+$/, "Letters, numbers, and hyphens only.")
    .optional(),
  label: z.string().max(200).optional(),
  // Bounded well below int4's ~2.1B ceiling — an admin-typed value, but still
  // a column that could otherwise overflow on a stray extra digit.
  maxUses: z.number().int().min(1).max(1_000_000).nullable().optional(),
  expiresAt: IsoDateTime.nullable().optional(),
});
export type AdminCreateReferralCodeRequest = z.infer<typeof AdminCreateReferralCodeRequest>;

// ---- PUT /v1/admin/referral-codes/:id ----
export const AdminUpdateReferralCodeRequest = z.object({
  label: z.string().max(200).nullable().optional(),
  isActive: z.boolean().optional(),
  maxUses: z.number().int().min(1).max(1_000_000).nullable().optional(),
  expiresAt: IsoDateTime.nullable().optional(),
});
export type AdminUpdateReferralCodeRequest = z.infer<typeof AdminUpdateReferralCodeRequest>;
