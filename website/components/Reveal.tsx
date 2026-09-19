"use client";

import { motion, useInView, useReducedMotion } from "motion/react";
import { useRef, type ReactNode } from "react";
import { springSoft } from "@/lib/motion";

export function Reveal({
  children,
  className = "",
  delay = 0,
}: {
  children: ReactNode;
  className?: string;
  delay?: number;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const reduced = useReducedMotion();
  const inView = useInView(ref, { once: true, margin: "0px 0px -10% 0px", amount: 0.2 });

  return (
    <motion.div
      ref={ref}
      className={className}
      initial={reduced ? { opacity: 0 } : { opacity: 0, y: 32 }}
      animate={inView ? (reduced ? { opacity: 1 } : { opacity: 1, y: 0 }) : undefined}
      transition={{ ...springSoft, delay: delay / 1000 }}
    >
      {children}
    </motion.div>
  );
}
