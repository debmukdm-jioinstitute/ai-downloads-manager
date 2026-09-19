"use client";

import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useState } from "react";
import { springDrawer, springSnappy } from "@/lib/motion";

type Item = { q: string; a: string };

export function FaqList({ items }: { items: Item[] }) {
  const [open, setOpen] = useState<number | null>(null);
  const reduced = useReducedMotion();

  return (
    <div className="faq mt-4">
      {items.map((item, i) => {
        const isOpen = open === i;
        return (
          <div key={item.q} className="border-b border-black/8 py-1">
            <button
              type="button"
              className="faq-trigger flex w-full items-center justify-between gap-6 py-5 text-left text-[19px] font-semibold tracking-tight"
              aria-expanded={isOpen}
              onClick={() => setOpen(isOpen ? null : i)}
            >
              {item.q}
              <motion.span
                className="faq-icon text-[#86868b]"
                animate={{ rotate: isOpen ? 45 : 0 }}
                transition={springSnappy}
              >
                +
              </motion.span>
            </button>
            <AnimatePresence initial={false}>
              {isOpen && (
                <motion.div
                  key="panel"
                  initial={reduced ? { opacity: 0 } : { opacity: 0, height: 0 }}
                  animate={reduced ? { opacity: 1 } : { opacity: 1, height: "auto" }}
                  exit={reduced ? { opacity: 0 } : { opacity: 0, height: 0 }}
                  transition={springDrawer}
                  className="overflow-hidden"
                >
                  <p className="pb-5 max-w-[60ch] text-[16px] leading-relaxed text-[#6e6e73]">{item.a}</p>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        );
      })}
    </div>
  );
}
