import { cookies } from "next/headers";
import { ADMIN_COOKIE_NAME } from "./session-constants";

export { ADMIN_COOKIE_NAME };

/** Read the admin session token from the incoming request's cookie. Valid in
 * Server Components, Route Handlers, and Server Actions. */
export async function getAdminToken(): Promise<string | undefined> {
  const store = await cookies();
  return store.get(ADMIN_COOKIE_NAME)?.value;
}

/** Set the httpOnly admin session cookie. Only callable from a Server Action
 * or Route Handler — Next.js forbids cookie writes during plain render.
 * `expiresAt` is the authoritative expiry from the login response (mirrors
 * the backend's actual session TTL) rather than a hardcoded duplicate. */
export async function setAdminToken(token: string, expiresAt: string): Promise<void> {
  const store = await cookies();
  store.set(ADMIN_COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    expires: new Date(expiresAt),
  });
}

export async function clearAdminToken(): Promise<void> {
  const store = await cookies();
  store.delete(ADMIN_COOKIE_NAME);
}
