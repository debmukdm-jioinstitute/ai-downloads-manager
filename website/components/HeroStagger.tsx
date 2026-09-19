"use client";

import { motion, useReducedMotion } from "motion/react";
import type { ReactNode } from "react";
import { springSoft } from "@/lib/motion";

export function HeroStagger({ children }: { children: ReactNode }) {
  const reduced = useReducedMotion();
  return (
    <motion.div
      initial="hidden"
      animate="visible"
      variants={{
        hidden: {},
        visible: {
          transition: reduced ? { staggerChildren: 0 } : { staggerChildren: 0.09, delayChildren: 0.04 },
        },
      }}
    >
      {children}
    </motion.div>
  );
}

export function HeroItem({ children, className = "" }: { children: ReactNode; className?: string }) {
  const reduced = useReducedMotion();
  return (
    <motion.div
      className={className}
      variants={{
        hidden: reduced ? { opacity: 0 } : { opacity: 0, y: 26 },
        visible: { opacity: 1, y: 0 },
      }}
      transition={springSoft}
    >
      {children}
    </motion.div>
  );
}
