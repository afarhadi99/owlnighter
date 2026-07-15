import { NextRequest, NextResponse } from "next/server";
import { ADMIN_COOKIE_NAME } from "./lib/session-constants";

const PUBLIC_PATHS = new Set(["/login", "/signup"]);

/** Presence-only check — is a session cookie attached at all? Full validity
 * (expired/revoked) is enforced by every page's own admin_panel-guarded API
 * call, which already 401s and renders an inline error today; this middleware
 * only needs to keep an unauthenticated visitor out of the sidebar/pages. */
export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  if (PUBLIC_PATHS.has(pathname)) return NextResponse.next();

  const token = req.cookies.get(ADMIN_COOKIE_NAME)?.value;
  if (!token) return NextResponse.redirect(new URL("/login", req.url));
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
