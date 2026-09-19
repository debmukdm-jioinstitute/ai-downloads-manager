import { auth } from "@/auth";
import { NextResponse } from "next/server";

export default auth((req) => {
  const { pathname } = req.nextUrl;
  const isProtected = pathname.startsWith("/account") || pathname.startsWith("/api/auth/desktop-token");

  if (isProtected && !req.auth) {
    const login = new URL("/login", req.nextUrl.origin);
    login.searchParams.set("callbackUrl", pathname);
    return NextResponse.redirect(login);
  }

  return NextResponse.next();
});

export const config = {
  matcher: ["/account/:path*", "/api/auth/desktop-token"],
};
