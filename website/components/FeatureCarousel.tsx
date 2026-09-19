"use client";

import { useEffect, useRef, useState } from "react";

const tiles = [
  {
    tone: "light" as const,
    kicker: "Watcher",
    title: "It waits until the download is real.",
    copy: "Partial .crdownload files are ignored. When the file settles, Nest reads text, metadata, and OCR — then names what it is.",
  },
  {
    tone: "blue" as const,
    kicker: "Search",
    title: "Ask the way you’d ask a person.",
    copy: "“Invoice from Amazon last month.” Nest ranks names, extracted text, OCR, tags, and metadata — not folder folklore.",
  },
  {
    tone: "dark" as const,
    kicker: "Dates",
    title: "A flight is not an expiry.",
    copy: "Nest hunts passports, renewals, and payment deadlines — and keeps event dates from becoming false alarms.",
  },
  {
    tone: "light" as const,
    kicker: "Voice",
    title: "Talk from anywhere on the Mac.",
    copy: "Hold ⌘⌥, or enable “Hey Nest.” Transcription stays on-device. Both are off until you choose them.",
  },
  {
    tone: "sand" as const,
    kicker: "Rules",
    title: "Nothing moves without you.",
    copy: "Review groups like “12 invoices → Finance.” Apply once. Undo anytime. Nest never deletes on its own.",
  },
  {
    tone: "dark" as const,
    kicker: "Privacy",
    title: "There is no Nest cloud.",
    copy: "Local rules work offline. Optional AI talks only to Ollama on your Mac. Your files never leave the machine.",
  },
];

export function FeatureCarousel() {
  const scroller = useRef<HTMLDivElement>(null);
  const [active, setActive] = useState(0);

  useEffect(() => {
    const el = scroller.current;
    if (!el) return;
    const onScroll = () => {
      const cards = [...el.querySelectorAll<HTMLElement>("[data-tile]")];
      const mid = el.scrollLeft + el.clientWidth / 2;
      let best = 0;
      let dist = Infinity;
      cards.forEach((card, i) => {
        const c = card.offsetLeft + card.offsetWidth / 2;
        const d = Math.abs(c - mid);
        if (d < dist) {
          dist = d;
          best = i;
        }
      });
      setActive(best);
    };
    el.addEventListener("scroll", onScroll, { passive: true });
    return () => el.removeEventListener("scroll", onScroll);
  }, []);

  const go = (dir: number) => {
    const el = scroller.current;
    if (!el) return;
    el.scrollBy({ left: dir * (el.clientWidth * 0.72), behavior: "smooth" });
  };

  return (
    <section id="gallery" className="bg-white py-24 md:py-32">
      <div className="mx-auto max-w-[980px] px-6">
        <p className="eyebrow">A closer look</p>
        <h2 className="display mt-3 max-w-[16ch] text-[40px] md:text-[56px]">Every surface, considered.</h2>
        <p className="mt-5 max-w-[46ch] text-[19px] leading-relaxed text-[#6e6e73]">
          Swipe the film. Nest is a quiet Mac app — watcher, librarian, and private assistant — designed to disappear until you need it.
        </p>
      </div>

      <div className="relative mt-12">
        <div
          ref={scroller}
          className="slider-track flex snap-x snap-mandatory gap-5 overflow-x-auto px-[max(1.5rem,calc((100%-980px)/2))] pb-4"
        >
          {tiles.map((tile) => (
            <article
              key={tile.kicker}
              data-tile
              className={`tile snap-center shrink-0 ${toneClass(tile.tone)}`}
            >
              <p className="text-[12px] font-semibold tracking-[0.16em] uppercase opacity-70">{tile.kicker}</p>
              <h3 className="display mt-6 max-w-[12ch] text-[32px] md:text-[40px]">{tile.title}</h3>
              <p className="mt-5 max-w-[36ch] text-[17px] leading-relaxed opacity-80">{tile.copy}</p>
            </article>
          ))}
        </div>

        <div className="mx-auto mt-8 flex max-w-[980px] items-center justify-between px-6">
          <div className="flex gap-2">
            {tiles.map((t, i) => (
              <span
                key={t.kicker}
                className={`h-1.5 rounded-full transition-all ${i === active ? "w-7 bg-[#1d1d1f]" : "w-1.5 bg-[#d2d2d7]"}`}
              />
            ))}
          </div>
          <div className="flex gap-2">
            <button type="button" className="nav-fab" onClick={() => go(-1)} aria-label="Previous">
              ‹
            </button>
            <button type="button" className="nav-fab" onClick={() => go(1)} aria-label="Next">
              ›
            </button>
          </div>
        </div>
      </div>
    </section>
  );
}

function toneClass(tone: (typeof tiles)[number]["tone"]) {
  switch (tone) {
    case "dark":
      return "bg-[#1d1d1f] text-white";
    case "blue":
      return "bg-gradient-to-br from-[#0a84ff] to-[#0071e3] text-white";
    case "sand":
      return "bg-[#f5f1ea] text-[#1d1d1f]";
    default:
      return "bg-[#f5f5f7] text-[#1d1d1f]";
  }
}
