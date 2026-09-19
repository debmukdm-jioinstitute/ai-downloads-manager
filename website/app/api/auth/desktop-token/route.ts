import { auth } from "@/auth";
import { createDesktopToken } from "@/lib/desktop-token";
import { NextResponse } from "next/server";

export async function GET() {
  const session = await auth();
  if (!session?.user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const token = await createDesktopToken(session);
    return NextResponse.json({
      token,
      user: {
        id: session.user.id,
        email: session.user.email,
        name: session.user.name,
        image: session.user.image,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Token error";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
