import { z } from "zod";
import { IsoDateTime, Uuid } from "./common.js";

const MYTSI_EMAIL = /^[^\s@]+@mytsi\.org$/i;

// ---- POST /v1/admin/auth/signup ----
export const AdminSignupRequest = z.object({
  email: z
    .string()
    .email()
    .regex(MYTSI_EMAIL, { message: "Only @mytsi.org email addresses may request admin access." }),
  password: z.string().min(8).max(200),
});
export type AdminSignupRequest = z.infer<typeof AdminSignupRequest>;

export const AdminSignupResponse = z.object({
  status: z.literal("pending"),
  message: z.string(),
});
export type AdminSignupResponse = z.infer<typeof AdminSignupResponse>;

// ---- POST /v1/admin/auth/login ----
export const AdminLoginRequest = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});
export type AdminLoginRequest = z.infer<typeof AdminLoginRequest>;

export const AdminLoginResponse = z.object({
  token: z.string(),
  expiresAt: IsoDateTime,
  account: z.object({ id: Uuid, email: z.string() }),
});
export type AdminLoginResponse = z.infer<typeof AdminLoginResponse>;

// ---- GET /v1/admin/auth/me ----
export const AdminMeResponse = z.object({
  id: Uuid,
  email: z.string(),
  isAdmin: z.boolean(),
});
export type AdminMeResponse = z.infer<typeof AdminMeResponse>;

// ---- GET /v1/admin/accounts/pending ----
export const AdminAccountStatus = z.enum(["pending", "approved", "rejected"]);
export type AdminAccountStatus = z.infer<typeof AdminAccountStatus>;

export const AdminPendingAccount = z.object({
  id: Uuid,
  email: z.string(),
  status: AdminAccountStatus,
  createdAt: IsoDateTime,
});
export type AdminPendingAccount = z.infer<typeof AdminPendingAccount>;

export const AdminPendingAccountsResponse = z.object({
  accounts: z.array(AdminPendingAccount),
});
export type AdminPendingAccountsResponse = z.infer<typeof AdminPendingAccountsResponse>;

// ---- POST /v1/admin/accounts/:id/approve, /v1/admin/accounts/:id/reject ----
export const AdminAccountActionResponse = z.object({
  id: Uuid,
  status: z.enum(["approved", "rejected"]),
});
export type AdminAccountActionResponse = z.infer<typeof AdminAccountActionResponse>;
