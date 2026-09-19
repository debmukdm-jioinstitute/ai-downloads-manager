"use client";

import { motion, useReducedMotion, useScroll, useTransform } from "motion/react";
import { useRef, type ReactNode } from "react";
import { springSoft } from "@/lib/motion";

export function HeroParallax({ children }: { children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  const reduced = useReducedMotion();
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ["start start", "end start"],
  });
  const y = useTransform(scrollYProgress, [0, 1], [0, reduced ? 0 : 48]);
  const scale = useTransform(scrollYProgress, [0, 1], [1, reduced ? 1 : 0.94]);
  const opacity = useTransform(scrollYProgress, [0, 0.85, 1], [1, 1, reduced ? 1 : 0.55]);

  return (
    <div ref={ref} className="relative mx-auto mt-16 max-w-[1100px] px-6 [&_.float-b]:absolute [&_.float-c]:absolute">
      <motion.div style={{ y, scale, opacity }} transition={springSoft}>
        {children}
      </motion.div>
    </div>
  );
}
