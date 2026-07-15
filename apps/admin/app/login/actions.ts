"use server";
import { redirect } from "next/navigation";
import { api, ApiRequestError } from "@/lib/api";
import { setAdminToken } from "@/lib/session";

export interface LoginActionState {
  error?: string;
}

export async function loginAction(
  _prevState: LoginActionState,
  formData: FormData,
): Promise<LoginActionState> {
  const email = String(formData.get("email") ?? "");
  const password = String(formData.get("password") ?? "");
  try {
    const res = await api.adminLogin({ email, password });
    await setAdminToken(res.token, res.expiresAt);
  } catch (err) {
    if (err instanceof ApiRequestError) return { error: err.body?.error.message ?? "Login failed." };
    return { error: "Login failed." };
  }
  redirect("/");
}
