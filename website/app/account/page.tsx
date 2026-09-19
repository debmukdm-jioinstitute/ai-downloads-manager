import { auth, signOut } from "@/auth";
import { Nav } from "@/components/Nav";
import Image from "next/image";
import Link from "next/link";
import { redirect } from "next/navigation";

export default async function AccountPage() {
  const session = await auth();
  if (!session?.user) {
    redirect("/login?callbackUrl=/account");
  }

  return (
    <div className="min-h-screen bg-[#f5f5f7]">
      <Nav />
      <main className="mx-auto max-w-[640px] px-6 pb-24 pt-28 md:pt-32">
        <p className="eyebrow">Your account</p>
        <h1 className="display mt-3 text-[36px] md:text-[44px]">You&apos;re signed in.</h1>
        <p className="mt-4 text-[16px] leading-relaxed text-[#6e6e73]">
          Nest stays local-first. Your account is for sign-in, releases, and anything we add later — not for uploading
          your Downloads folder.
        </p>

        <div className="material-card mt-10 flex items-center gap-5 rounded-[28px] p-8">
          {session.user.image ? (
            <Image
              src={session.user.image}
              alt=""
              width={56}
              height={56}
              className="rounded-full"
              unoptimized
            />
          ) : (
            <div className="flex h-14 w-14 items-center justify-center rounded-full bg-[#1d1d1f] text-[20px] font-semibold text-white">
              {(session.user.name ?? session.user.email ?? "?").slice(0, 1).toUpperCase()}
            </div>
          )}
          <div className="min-w-0">
            <p className="truncate text-[19px] font-semibold tracking-tight">{session.user.name ?? "Nest user"}</p>
            <p className="truncate text-[14px] text-[#6e6e73]">{session.user.email}</p>
          </div>
        </div>

        <div className="mt-8 flex flex-wrap gap-4">
          <form
            action={async () => {
              "use server";
              await signOut({ redirectTo: "/" });
            }}
          >
            <button type="submit" className="pill">
              Sign out
            </button>
          </form>
          <Link href="/" className="pill-ghost inline-flex items-center">
            Home
          </Link>
        </div>
      </main>
    </div>
  );
}
