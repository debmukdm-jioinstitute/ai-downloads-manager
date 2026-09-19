import { auth } from "@/auth";
import { Nav } from "@/components/Nav";
import { redirect } from "next/navigation";
import { MacAuthRedirect } from "./MacAuthRedirect";

export default async function MacCallbackPage() {
  const session = await auth();
  if (!session?.user) {
    redirect("/login?client=mac");
  }

  return (
    <div className="min-h-screen bg-[#f5f5f7]">
      <Nav />
      <main className="mx-auto max-w-[480px] px-6 pb-24 pt-28 md:pt-32">
        <p className="eyebrow text-center">Mac</p>
        <h1 className="display mt-3 text-center text-[32px]">Almost there.</h1>
        <div className="mt-10">
          <MacAuthRedirect />
        </div>
      </main>
    </div>
  );
}
