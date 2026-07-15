"use server";
import { redirect } from "next/navigation";
import { api } from "./api";
import { clearAdminToken } from "./session";

export async function logoutAction(): Promise<void> {
  try {
    await api.adminLogout();
  } catch {
    // Session may already be invalid/expired server-side; clear the cookie regardless.
  }
  await clearAdminToken();
  redirect("/login");
}
