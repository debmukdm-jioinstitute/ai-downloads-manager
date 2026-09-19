import { redirect } from "next/navigation";

export default async function SignupPage({
  searchParams,
}: {
  searchParams: Promise<{ client?: string }>;
}) {
  const params = await searchParams;
  const query = new URLSearchParams();
  if (params.client) query.set("client", params.client);
  const suffix = query.toString() ? `?${query.toString()}` : "";
  redirect(`/login${suffix}`);
}
