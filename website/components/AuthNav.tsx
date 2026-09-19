"use client";

import { signIn, signOut, useSession } from "next-auth/react";
import Link from "next/link";
import { springSnappy } from "@/lib/motion";
import { motion } from "motion/react";

export function AuthNav() {
  const { data: session, status } = useSession();

  if (status === "loading") {
    return <span className="hidden text-[12px] text-[#86868b] md:inline">…</span>;
  }

  if (session?.user) {
    return (
      <div className="hidden items-center gap-4 md:flex">
        <Link href="/account" className="nav-link max-w-[140px] truncate text-[12px]">
          {session.user.name ?? session.user.email ?? "Account"}
        </Link>
        <motion.button
          type="button"
          className="text-[12px] text-[#0071e3]"
          onClick={() => signOut({ callbackUrl: "/" })}
          whileTap={{ scale: 0.96 }}
          transition={springSnappy}
        >
          Sign out
        </motion.button>
      </div>
    );
  }

  return (
    <Link href="/login" className="hidden text-[12px] text-[#0071e3] hover:text-[#0077ed] md:inline">
      Sign in
    </Link>
  );
}

export function AuthNavMobileSignIn() {
  const { data: session, status } = useSession();
  if (status !== "unauthenticated") return null;

  return (
    <button type="button" className="text-[12px] text-[#0071e3] md:hidden" onClick={() => signIn()}>
      Sign in
    </button>
  );
}
