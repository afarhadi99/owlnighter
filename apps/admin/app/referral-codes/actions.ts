"use server";
import { revalidatePath } from "next/cache";
import { api, ApiRequestError } from "@/lib/api";

export interface CreateCodeState {
  error?: string;
  success?: boolean;
}

export async function createReferralCodeAction(
  _prevState: CreateCodeState,
  formData: FormData,
): Promise<CreateCodeState> {
  const code = String(formData.get("code") ?? "").trim();
  const label = String(formData.get("label") ?? "").trim();
  const maxUsesRaw = String(formData.get("maxUses") ?? "").trim();
  const expiresAtRaw = String(formData.get("expiresAt") ?? "").trim();

  try {
    await api.adminCreateReferralCode({
      code: code.length > 0 ? code : undefined,
      label: label.length > 0 ? label : undefined,
      maxUses: maxUsesRaw.length > 0 ? Number(maxUsesRaw) : null,
      // A bare <input type="date"> value has no time component; the API
      // validates this as a full ISO datetime, so anchor it to end-of-day UTC.
      expiresAt: expiresAtRaw.length > 0 ? `${expiresAtRaw}T23:59:59.000Z` : null,
    });
  } catch (err) {
    return { error: err instanceof ApiRequestError ? (err.body?.error.message ?? "Create failed.") : "Create failed." };
  }
  revalidatePath("/referral-codes");
  return { success: true };
}

export interface ToggleCodeState {
  error?: string;
}

export async function toggleReferralCodeAction(
  id: string,
  isActive: boolean,
  _prevState: ToggleCodeState,
): Promise<ToggleCodeState> {
  try {
    await api.adminUpdateReferralCode(id, { isActive });
  } catch (err) {
    return { error: err instanceof ApiRequestError ? (err.body?.error.message ?? "Update failed.") : "Update failed." };
  }
  revalidatePath("/referral-codes");
  return {};
}
