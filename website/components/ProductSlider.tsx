"use client";

import { useEffect, useRef, useState } from "react";

const slides = [
  {
    kicker: "Overview",
    title: "See the day at a glance.",
    copy: "What arrived. What’s still unorganized. What needs you today — including dates that are about to matter.",
    scene: "overview" as const,
  },
  {
    kicker: "Search",
    title: "Ask the way you’d ask a person.",
    copy: "“Invoice from Amazon last month.” “Receipts over ₹5,000.” Nest looks through names, text, and tags — not just folders.",
    scene: "search" as const,
  },
  {
    kicker: "Expiry Center",
    title: "Deadlines, caught in the document.",
    copy: "Passports, policies, payments. Nest reads the dates that matter, and ignores the ones that don’t.",
    scene: "expiry" as const,
  },
  {
    kicker: "Voice",
    title: "Talk to Nest from anywhere.",
    copy: "Hold ⌘⌥, or say “Hey Nest.” It listens on your Mac and opens the search you meant.",
    scene: "voice" as const,
  },
  {
    kicker: "Rules",
    title: "Organize in batches. You stay in charge.",
    copy: "Nest proposes where files should live. Nothing moves until you review and apply.",
    scene: "rules" as const,
  },
];

export function ProductSlider() {
  const [index, setIndex] = useState(0);
  const hover = useRef(false);

  useEffect(() => {
    const id = window.setInterval(() => {
      if (!hover.current) setIndex((i) => (i + 1) % slides.length);
    }, 5200);
    return () => window.clearInterval(id);
  }, []);

  const slide = slides[index];

  return (
    <section
      id="gallery"
      className="bg-white py-24 md:py-32"
      onMouseEnter={() => {
        hover.current = true;
      }}
      onMouseLeave={() => {
        hover.current = false;
      }}
    >
      <div className="mx-auto max-w-[980px] px-6">
        <p className="eyebrow">A closer look</p>
        <h2 className="display mt-3 max-w-[18ch] text-[40px] md:text-[56px]">{slide.title}</h2>
        <p className="mt-5 max-w-[52ch] text-[19px] leading-relaxed text-[#6e6e73] md:text-[21px]">{slide.copy}</p>

        <div className="mt-12 overflow-hidden rounded-[28px] mac-chrome">
          <div className="flex items-center gap-2 px-4 py-3">
            <span className="dot traffic-red" />
            <span className="dot traffic-yellow" />
            <span className="dot traffic-green" />
            <span className="ml-3 text-[12px] text-[#6e6e73]">{slide.kicker}</span>
          </div>
          <div className="bg-[#f5f5f7] p-3 md:p-5">
            <MacScene scene={slide.scene} />
          </div>
        </div>

        <div className="mt-8 flex flex-wrap items-center justify-center gap-2">
          {slides.map((s, i) => (
            <button
              key={s.kicker}
              onClick={() => setIndex(i)}
              className={`rounded-full px-4 py-2 text-[13px] transition ${
                i === index ? "bg-[#1d1d1f] text-white" : "bg-[#e8e8ed] text-[#1d1d1f] hover:bg-[#d2d2d7]"
              }`}
            >
              {s.kicker}
            </button>
          ))}
        </div>
      </div>
    </section>
  );
}

function MacScene({ scene }: { scene: (typeof slides)[number]["scene"] }) {
  return (
    <div className="grid min-h-[340px] overflow-hidden rounded-2xl bg-white shadow-[0_1px_2px_rgba(0,0,0,0.06)] md:grid-cols-[200px_1fr] md:min-h-[420px]">
      <aside className="hidden border-r border-black/5 bg-[#f6f6f8] p-4 md:block">
        <p className="mb-4 px-2 text-[11px] font-semibold uppercase tracking-[0.14em] text-[#86868b]">Nest</p>
        {["Overview", "All Files", "Categories", "Expiry Center", "Search", "Rules", "Activity"].map((item) => {
          const active =
            (scene === "overview" && item === "Overview") ||
            (scene === "search" && item === "Search") ||
            (scene === "expiry" && item === "Expiry Center") ||
            (scene === "rules" && item === "Rules") ||
            (scene === "voice" && item === "Search");
          return (
            <div
              key={item}
              className={`rounded-lg px-3 py-1.5 text-[13px] ${active ? "bg-[#0071e3] text-white" : "text-[#1d1d1f]/80"}`}
            >
              {item}
            </div>
          );
        })}
      </aside>
      <div className="p-5 md:p-8">
        {scene === "overview" && <OverviewScene />}
        {scene === "search" && <SearchScene />}
        {scene === "expiry" && <ExpiryScene />}
        {scene === "voice" && <VoiceScene />}
        {scene === "rules" && <RulesScene />}
      </div>
    </div>
  );
}

function OverviewScene() {
  const cards = [
    { label: "Processed today", value: "47" },
    { label: "Unorganized", value: "12" },
    { label: "Needs attention", value: "3" },
  ];
  return (
    <div>
      <h3 className="text-[22px] font-semibold tracking-tight">Good evening</h3>
      <p className="mt-1 text-[14px] text-[#6e6e73]">Your Downloads, quietly in order.</p>
      <div className="mt-6 grid grid-cols-3 gap-3">
        {cards.map((c) => (
          <div key={c.label} className="rounded-2xl bg-[#f5f5f7] p-4">
            <div className="text-[28px] font-semibold tracking-tight">{c.value}</div>
            <div className="mt-1 text-[12px] text-[#6e6e73]">{c.label}</div>
          </div>
        ))}
      </div>
      <div className="mt-5 rounded-2xl border border-black/5 p-4">
        <p className="text-[12px] font-semibold text-[#86868b]">Today’s Attention</p>
        <Row name="Passport_Scan.pdf" meta="Expires in 18 days" />
        <Row name="Health_Insurance.pdf" meta="Renewal · 30 Mar" />
        <Row name="Rent_Agreement.pdf" meta="Deadline · 1 Oct" />
      </div>
    </div>
  );
}

function SearchScene() {
  return (
    <div>
      <div className="rounded-full bg-[#f5f5f7] px-4 py-3 text-[15px] text-[#1d1d1f]">
        invoice from Amazon last month
      </div>
      <div className="mt-6 space-y-2">
        <Row name="Amazon_Invoice_Aug.pdf" meta="Finance · Invoice · ₹4,299" strong />
        <Row name="Amazon_Order_8821.pdf" meta="Finance · Receipt" />
        <Row name="AWS_Invoice_August.pdf" meta="Work · Invoice" />
      </div>
    </div>
  );
}

function ExpiryScene() {
  return (
    <div>
      <h3 className="text-[20px] font-semibold">Expiry Center</h3>
      <div className="mt-5 grid gap-3">
        <Chip label="Expired" count="1" tone="rose" />
        <Chip label="Expiring soon" count="2" tone="amber" />
        <Chip label="Upcoming" count="6" tone="green" />
      </div>
      <p className="mt-6 text-[13px] leading-relaxed text-[#6e6e73]">
        Detected in source text: “valid until 12 March 2027” — classified as expiry, not a flight date.
      </p>
    </div>
  );
}

function VoiceScene() {
  return (
    <div className="flex h-full min-h-[280px] flex-col items-center justify-center text-center">
      <div className="relative grid h-24 w-24 place-items-center rounded-full bg-[#0071e3]/10">
        <div className="absolute inset-0 animate-ping rounded-full bg-[#0071e3]/10" />
        <div className="h-16 w-16 rounded-full bg-[#0071e3] shadow-lg shadow-[#0071e3]/30" />
      </div>
      <p className="mt-8 text-[20px] font-semibold tracking-tight">Listening…</p>
      <p className="mt-2 max-w-[32ch] text-[14px] text-[#6e6e73]">“Hey Nest, find the boarding pass for next Tuesday.”</p>
    </div>
  );
}

function RulesScene() {
  return (
    <div>
      <h3 className="text-[20px] font-semibold">Organize Downloads</h3>
      <p className="mt-1 text-[13px] text-[#6e6e73]">Review the groups, then apply. Always reversible.</p>
      <div className="mt-5 space-y-3">
        <RuleRow title="12 invoices → Finance / Invoices" />
        <RuleRow title="8 screenshots → Images / Screenshots" />
        <RuleRow title="4 assignments → Education / Assignments" />
      </div>
    </div>
  );
}

function Row({ name, meta, strong }: { name: string; meta: string; strong?: boolean }) {
  return (
    <div className={`flex items-center justify-between border-b border-black/5 py-3 last:border-0 ${strong ? "font-medium" : ""}`}>
      <span className="text-[14px]">{name}</span>
      <span className="text-[12px] text-[#6e6e73]">{meta}</span>
    </div>
  );
}

function Chip({ label, count, tone }: { label: string; count: string; tone: "rose" | "amber" | "green" }) {
  const map = {
    rose: "bg-[#fff1f0] text-[#c41e3a]",
    amber: "bg-[#fff8eb] text-[#b25000]",
    green: "bg-[#f0fff4] text-[#248a3d]",
  };
  return (
    <div className={`flex items-center justify-between rounded-2xl px-4 py-3 ${map[tone]}`}>
      <span className="text-[14px] font-medium">{label}</span>
      <span className="text-[20px] font-semibold">{count}</span>
    </div>
  );
}

function RuleRow({ title }: { title: string }) {
  return (
    <div className="flex items-center justify-between rounded-2xl bg-[#f5f5f7] px-4 py-3">
      <span className="text-[14px]">{title}</span>
      <span className="text-[12px] font-medium text-[#0071e3]">Review</span>
    </div>
  );
}
