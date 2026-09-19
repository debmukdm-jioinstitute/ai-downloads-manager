/** Apple-style springs (WWDC *Designing Fluid Interfaces*) → Motion mapping */
export const springSnappy = { type: "spring" as const, bounce: 0, duration: 0.4 };
export const springDrawer = { type: "spring" as const, bounce: 0.2, duration: 0.35 };
export const springSoft = { type: "spring" as const, bounce: 0, duration: 0.55 };
export const easeApple = [0.22, 1, 0.36, 1] as const;
