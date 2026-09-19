"use client";

import { DMG_URL } from "@/lib/links";
import { useEffect, useState } from "react";

export function Nav() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header className={`fixed inset-x-0 top-0 z-50 ${scrolled ? "nav-blur" : "bg-transparent"}`}>
      <div className="mx-auto flex h-12 max-w-[980px] items-center justify-between px-6 text-[12px] md:h-[44px]">
        <a href="#top" className="flex items-center gap-2 font-semibold tracking-tight">
          <Logo />
          Nest
        </a>
        <nav className="hidden items-center gap-7 text-[12px] text-[#1d1d1f]/80 md:flex">
          <a href="#understand" className="hover:text-black">
            Understand
          </a>
          <a href="#gallery" className="hover:text-black">
            Gallery
          </a>
          <a href="#search" className="hover:text-black">
            Search
          </a>
          <a href="#privacy" className="hover:text-black">
            Privacy
          </a>
          <a href="#install" className="hover:text-black">
            Install
          </a>
        </nav>
        <a href={DMG_URL} className="rounded-full bg-[#0071e3] px-3 py-[5px] text-[12px] text-white hover:bg-[#0077ed]">
          Download
        </a>
      </div>
    </header>
  );
}

export function Logo({ className = "h-[18px] w-[18px]" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 32 32" fill="none" aria-hidden>
      <rect width="32" height="32" rx="8" fill="#1d1d1f" />
      <path
        d="M8 20.5c0-4.2 3.1-7.5 8-8.5 4.9 1 8 4.3 8 8.5 0 1.7-1.4 2.5-3.2 2.5H11.2C9.4 23 8 22.2 8 20.5Z"
        fill="#f5f5f7"
      />
      <path d="M12 13.2c1.2-2.2 2.6-3.6 4-4.2 1.4.6 2.8 2 4 4.2" stroke="#86868b" strokeWidth="1.4" strokeLinecap="round" />
    </svg>
  );
}
