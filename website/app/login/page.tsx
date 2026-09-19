import { auth, oauthProvidersEnabled } from "@/auth";
import { OAuthLogin } from "@/components/OAuthLogin";
import { Nav } from "@/components/Nav";
import Link from "next/link";
import { redirect } from "next/navigation";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ callbackUrl?: string; client?: string }>;
}) {
  const params = await searchParams;
  const session = await auth();
  const providers = oauthProvidersEnabled();

  const isMac = params.client === "mac";
  const defaultCallback = isMac ? "/auth/mac-callback" : "/account";
  const callbackUrl = params.callbackUrl ?? defaultCallback;

  if (session?.user) {
    redirect(callbackUrl);
  }

  return (
    <div className="min-h-screen bg-[#f5f5f7]">
      <Nav />
      <main className="mx-auto flex max-w-[480px] flex-col px-6 pb-24 pt-28 md:pt-32">
        <p className="eyebrow text-center">Account</p>
        <h1 className="display mt-3 text-center text-[36px] md:text-[44px]">
          {isMac ? "Sign in to link Nest on your Mac" : "Sign in to Nest"}
        </h1>
        <p className="mx-auto mt-4 max-w-[36ch] text-center text-[16px] leading-relaxed text-[#6e6e73]">
          {isMac
            ? "One OAuth tap in the browser, then Nest opens automatically. Your files still stay on your Mac — this is only for your Nest account."
            : "Create an account or sign in with GitHub or Google. No passwords to remember."}
        </p>

        <div className="material-card mt-10 rounded-[28px] p-8">
          <OAuthLogin callbackUrl={callbackUrl} github={providers.github} google={providers.google} />
        </div>

        <p className="mt-8 text-center text-[13px] text-[#86868b]">
          <Link className="text-[#0071e3]" href="/">
            ← Back to home
          </Link>
        </p>
      </main>
    </div>
  );
}
