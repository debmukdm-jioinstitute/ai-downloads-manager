"use client";

import { signIn } from "next-auth/react";
import { motion } from "motion/react";
import { springSnappy } from "@/lib/motion";

type Props = {
  callbackUrl: string;
  github: boolean;
  google: boolean;
};

export function OAuthLogin({ callbackUrl, github, google }: Props) {
  const anyProvider = github || google;

  if (!anyProvider) {
    return (
      <div className="rounded-[20px] border border-amber-200 bg-amber-50 px-5 py-4 text-left text-[14px] leading-relaxed text-amber-950">
        OAuth isn&apos;t configured on this deployment yet. Add{" "}
        <code className="text-[13px]">AUTH_GITHUB_*</code> or <code className="text-[13px]">AUTH_GOOGLE_*</code> in Vercel
        environment variables, then redeploy.
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      {github && (
        <OAuthButton label="Continue with GitHub" onClick={() => signIn("github", { callbackUrl })} />
      )}
      {google && (
        <OAuthButton label="Continue with Google" onClick={() => signIn("google", { callbackUrl })} />
      )}
      <p className="mt-2 text-center text-[12px] leading-relaxed text-[#86868b]">
        No password. OAuth only — we never see your GitHub or Google password.
      </p>
    </div>
  );
}

function OAuthButton({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <motion.button
      type="button"
      className="oauth-btn"
      onClick={onClick}
      whileHover={{ scale: 1.01 }}
      whileTap={{ scale: 0.97 }}
      transition={springSnappy}
    >
      {label}
    </motion.button>
  );
}
