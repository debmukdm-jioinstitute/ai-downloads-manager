import { SignJWT, jwtVerify } from "jose";
import type { Session } from "next-auth";

function secretKey() {
  const secret = process.env.AUTH_SECRET;
  if (!secret) {
    throw new Error("AUTH_SECRET is not set");
  }
  return new TextEncoder().encode(secret);
}

export async function createDesktopToken(session: Session) {
  const sub = session.user?.id || session.user?.email;
  if (!sub) {
    throw new Error("Missing user identity for desktop token");
  }

  return new SignJWT({
    email: session.user?.email ?? null,
    name: session.user?.name ?? null,
    picture: session.user?.image ?? null,
  })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(sub)
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(secretKey());
}

export type DesktopTokenPayload = {
  sub: string;
  email: string | null;
  name: string | null;
  picture: string | null;
};

export async function verifyDesktopToken(token: string): Promise<DesktopTokenPayload | null> {
  try {
    const { payload } = await jwtVerify(token, secretKey());
    return {
      sub: String(payload.sub ?? ""),
      email: (payload.email as string | null) ?? null,
      name: (payload.name as string | null) ?? null,
      picture: (payload.picture as string | null) ?? null,
    };
  } catch {
    return null;
  }
}
