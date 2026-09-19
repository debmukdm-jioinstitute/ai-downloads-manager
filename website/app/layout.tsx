import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Nest — Your Downloads, understood.",
  description:
    "Nest is a native Mac app that watches your Downloads folder, understands each file, tracks the dates that matter, and finds anything you describe — privately, on your Mac.",
  metadataBase: new URL("https://nest.vercel.app"),
  openGraph: {
    title: "Nest for Mac",
    description: "A messy Downloads folder, made searchable. Local. Private. Yours.",
    type: "website",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className={`${inter.variable} antialiased`}>{children}</body>
    </html>
  );
}
