"use server";
import { api, ApiRequestError } from "@/lib/api";

export interface SignupActionState {
  error?: string;
  success?: boolean;
}

export async function signupAction(
  _prevState: SignupActionState,
  formData: FormData,
): Promise<SignupActionState> {
  const email = String(formData.get("email") ?? "");
  const password = String(formData.get("password") ?? "");
  try {
    await api.adminSignup({ email, password });
    return { success: true };
  } catch (err) {
    if (err instanceof ApiRequestError) return { error: err.body?.error.message ?? "Signup failed." };
    return { error: "Signup failed." };
  }
}
