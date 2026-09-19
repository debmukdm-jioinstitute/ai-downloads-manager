"use client";

import { useEffect, useState } from "react";

export function MacAuthRedirect() {
  const [error, setError] = useState<string | null>(null);
  const [deepLink, setDeepLink] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function run() {
      try {
        const res = await fetch("/api/auth/desktop-token");
        if (!res.ok) {
          const body = await res.json().catch(() => ({}));
          throw new Error(body.error ?? `Sign-in failed (${res.status})`);
        }
        const data = (await res.json()) as { token: string };
        const url = `nest://auth/callback?token=${encodeURIComponent(data.token)}`;
        if (cancelled) return;
        setDeepLink(url);
        window.location.href = url;
      } catch (e) {
        if (!cancelled) {
          setError(e instanceof Error ? e.message : "Could not finish Mac sign-in");
        }
      }
    }

    run();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="material-card rounded-[28px] p-8 text-center">
      {error ? (
        <>
          <p className="text-[17px] font-semibold text-[#1d1d1f]">Couldn&apos;t hand off to Nest</p>
          <p className="mt-3 text-[14px] leading-relaxed text-[#6e6e73]">{error}</p>
        </>
      ) : (
        <>
          <p className="text-[17px] font-semibold text-[#1d1d1f]">Opening Nest…</p>
          <p className="mt-3 text-[14px] leading-relaxed text-[#6e6e73]">
            If nothing happens, switch back to Nest or click the button below.
          </p>
          {deepLink && (
            <a className="pill mt-6 inline-flex" href={deepLink}>
              Open Nest
            </a>
          )}
        </>
      )}
    </div>
  );
}
