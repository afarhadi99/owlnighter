"use server";
import { revalidatePath } from "next/cache";
import { api } from "@/lib/api";

export async function approveAccountAction(id: string): Promise<void> {
  await api.adminApproveAccount(id);
  revalidatePath("/accounts");
}

export async function rejectAccountAction(id: string): Promise<void> {
  await api.adminRejectAccount(id);
  revalidatePath("/accounts");
}
