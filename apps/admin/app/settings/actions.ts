"use server";
import { revalidatePath } from "next/cache";
import { api, ApiRequestError } from "@/lib/api";

export interface UpdateSettingState {
  error?: string;
  success?: boolean;
}

export async function updateSettingAction(
  key: string,
  _prevState: UpdateSettingState,
  formData: FormData,
): Promise<UpdateSettingState> {
  const raw = formData.get("value");
  const type = String(formData.get("__type") ?? "string");

  // A blank secret submission means "leave unchanged" — never overwrite a
  // configured credential with an accidental empty value.
  if (type === "secret" && (!raw || String(raw).length === 0)) {
    return { success: true };
  }

  let value: unknown;
  if (type === "number") value = Number(raw);
  else if (type === "boolean") value = raw === "true";
  else value = String(raw ?? "");

  try {
    await api.adminPutSetting(key, value);
  } catch (err) {
    if (err instanceof ApiRequestError) return { error: err.body?.error.message ?? "Update failed." };
    return { error: "Update failed." };
  }
  revalidatePath("/settings");
  return { success: true };
}
