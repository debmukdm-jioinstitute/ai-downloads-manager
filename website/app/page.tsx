import { FeatureCarousel } from "@/components/FeatureCarousel";
import { Nav, Logo } from "@/components/Nav";
import { ProductSlider } from "@/components/ProductSlider";
import { Reveal } from "@/components/Reveal";
import { DMG_URL, GITHUB_URL, RELEASES_URL } from "@/lib/links";

const fileKinds = [
  "Invoices",
  "Passports",
  "Lecture slides",
  "Boarding passes",
  "Receipts",
  "Contracts",
  "Screenshots",
  "Insurance",
  "Assignments",
  "Bank statements",
  "IDs",
  "Presentations",
];

export default function HomePage() {
  return (
    <div id="top">
      <Nav />

      <section className="hero-mesh relative overflow-hidden pt-28 pb-16 md:pt-36 md:pb-24">
        <div className="mx-auto max-w-[980px] px-6 text-center">
          <p className="reveal eyebrow">Nest for Mac</p>
          <h1 className="display reveal delay-1 mx-auto mt-4 max-w-[14ch] text-[52px] md:text-[84px]">
            Your Downloads, understood.
          </h1>
          <p className="reveal delay-2 mx-auto mt-6 max-w-[40ch] text-[19px] leading-relaxed text-[#6e6e73] md:text-[21px]">
            Nest watches the folder that fills up fastest, works out what each file actually is, and finds it when you ask — in English, or out loud.
          </p>
          <div className="reveal delay-3 mt-8 flex flex-wrap items-center justify-center gap-4">
            <a className="pill" href={DMG_URL}>
              Download for Mac
            </a>
            <a className="pill-ghost" href="#install">
              How to install →
            </a>
          </div>
          <p className="reveal delay-4 mt-4 text-[12px] text-[#86868b]">
            Apple Silicon · macOS 14 Sonoma or later · Free
          </p>
        </div>

        <div className="relative mx-auto mt-16 max-w-[1100px] px-6">
          <div className="reveal delay-4">
            <HeroWindow />
          </div>
          <FloatingChip className="float-a -left-2 top-[10%] hidden lg:block" title="Invoice" sub="Finance" />
          <FloatingChip className="float-b -right-2 top-[6%] hidden md:block" title="Passport" sub="Expires 2027" />
          <FloatingChip className="float-c -left-1 bottom-[8%] hidden xl:block" title="Hey Nest" sub="Voice ready" />
        </div>
      </section>

      <section className="border-y border-black/5 bg-white py-6">
        <div className="marquee">
          <div className="marquee-track">
            {[...fileKinds, ...fileKinds].map((kind, i) => (
              <span key={`${kind}-${i}`} className="rounded-full bg-[#f5f5f7] px-5 py-2 text-[14px] text-[#1d1d1f]">
                {kind}
              </span>
            ))}
          </div>
        </div>
      </section>

      <section id="understand" className="py-24 md:py-32">
        <div className="mx-auto max-w-[980px] px-6">
          <Reveal>
            <p className="eyebrow">What Nest is</p>
            <h2 className="display mt-3 max-w-[18ch] text-[40px] md:text-[56px]">Three things. One quiet app.</h2>
          </Reveal>
          <div className="mt-16 grid gap-6 md:grid-cols-3">
            <Reveal delay={40}>
              <FeatureCard
                n="01"
                title="A watcher that waits until the file is real."
                body="The moment a download finishes, Nest reads it — text, metadata, even OCR on images — and names what it is. Partial downloads are ignored until they settle."
              />
            </Reveal>
            <Reveal delay={120}>
              <FeatureCard
                n="02"
                title="Intelligence that knows a flight from an expiry."
                body="Nest hunts for dates that matter: passport expiry, policy renewal, payment deadline. A boarding date stays an event. Ambiguous finds wait in Needs Review."
              />
            </Reveal>
            <Reveal delay={200}>
              <FeatureCard
                n="03"
                title="An assistant that never leaves your Mac."
                body="Type, or speak. Nest answers from what it already knows. Local rules work with zero setup. Optional AI runs through Ollama on your machine — never uploaded."
              />
            </Reveal>
          </div>
        </div>
      </section>

      <FeatureCarousel />
      <ProductSlider />

      <section id="search" className="bg-[#f5f5f7] py-24 md:py-32">
        <div className="mx-auto grid max-w-[980px] items-center gap-16 px-6 md:grid-cols-2">
          <Reveal>
            <p className="eyebrow">Search</p>
            <h2 className="display mt-3 text-[40px] md:text-[52px]">Stop remembering filenames.</h2>
            <p className="mt-5 text-[19px] leading-relaxed text-[#6e6e73]">
              Ask for the invoice from Amazon. The presentation from yesterday. Insurance documents. Nest ranks across names, extracted text, OCR, tags, and metadata.
            </p>
            <ul className="mt-8 space-y-3 text-[17px] text-[#1d1d1f]">
              <li>Natural language, not filters first.</li>
              <li>Optional AI turns “over ₹10,000 last month” into real constraints.</li>
              <li>Voice: hold ⌘⌥ anywhere, or enable “Hey Nest.”</li>
            </ul>
          </Reveal>
          <Reveal delay={120}>
            <QuoteStack />
          </Reveal>
        </div>
      </section>

      <section id="expiry" className="bg-white py-24 md:py-32">
        <div className="mx-auto max-w-[980px] px-6">
          <Reveal>
            <p className="eyebrow">Expiry Center</p>
            <h2 className="display mt-3 max-w-[16ch] text-[40px] md:text-[56px]">The dates inside your files, finally visible.</h2>
            <p className="mt-5 max-w-[54ch] text-[19px] leading-relaxed text-[#6e6e73]">
              Nest reads the document, not just the calendar. Confirm, correct, or ignore each detection. Add it to Calendar with a reminder. Scan the library you already had.
            </p>
          </Reveal>
          <div className="mt-14 grid gap-4 md:grid-cols-4">
            {[
              ["Expired", "Already past. Still in the pile."],
              ["Soon", "90 / 30 / 7 days — you choose."],
              ["Upcoming", "On the horizon, not urgent."],
              ["Needs review", "Low confidence never becomes a false alarm."],
            ].map(([t, d], i) => (
              <Reveal key={t} delay={i * 70}>
                <div className="h-full rounded-[28px] bg-[#f5f5f7] p-8">
                  <h3 className="text-[21px] font-semibold tracking-tight">{t}</h3>
                  <p className="mt-3 text-[15px] leading-relaxed text-[#6e6e73]">{d}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section id="privacy" className="dark-band py-24 md:py-32">
        <div className="mx-auto max-w-[980px] px-6">
          <Reveal>
            <p className="text-[12px] font-semibold tracking-[0.16em] text-[#86868b] uppercase">Privacy</p>
            <h2 className="display mt-3 max-w-[18ch] text-[40px] text-white md:text-[56px]">On your Mac. Or it doesn’t happen.</h2>
            <p className="mt-6 max-w-[50ch] text-[19px] leading-relaxed text-[#a1a1a6]">
              Classification, search, hashing, and OCR work fully offline. AI is optional, off until you turn it on, and talks only to a local Ollama model. Voice transcription stays on-device.
            </p>
          </Reveal>
          <div className="mt-14 grid gap-px overflow-hidden rounded-[28px] bg-white/10 md:grid-cols-3">
            {[
              ["Nothing uploaded", "Your files never leave the machine. There is no Nest cloud."],
              ["You approve every move", "Nest never deletes or relocates a file unless you say so. Every action is logged and undoable."],
              ["Optional, honestly", "Skip AI. Skip voice. Nest still classifies with local rules and remains useful."],
            ].map(([t, d]) => (
              <div key={t} className="bg-black p-8 md:p-10">
                <h3 className="text-[21px] font-semibold text-white">{t}</h3>
                <p className="mt-3 text-[15px] leading-relaxed text-[#a1a1a6]">{d}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="bg-[#f5f5f7] py-24 md:py-32">
        <div className="mx-auto max-w-[980px] px-6">
          <Reveal>
            <p className="eyebrow">Everyday</p>
            <h2 className="display mt-3 text-[40px] md:text-[56px]">Designed to disappear into the Mac you already have.</h2>
          </Reveal>
          <div className="mt-14 grid gap-6 md:grid-cols-2">
            <Spec
              title="Safe organization"
              body="Duplicates are flagged, never silently copied. Moves use Finder-style numbering if a name already exists. Undo is a first-class action."
            />
            <Spec
              title="Categories that match real life"
              body="Work, Finance, Education, Personal, Images, Other — with invoices, receipts, assignments, screenshots, and a Needs Review bucket when Nest isn’t sure."
            />
            <Spec
              title="Activity you can audit"
              body="A running log of detected, classified, moved, renamed, flagged, and undone. Nothing happens in the dark."
            />
            <Spec
              title="Talk to Nest"
              body="⌘⌥ from anywhere (Accessibility permission for global use). Optional wake word. Optional spoken confirmation. All of it off by default."
            />
          </div>
        </div>
      </section>

      <section id="install" className="bg-white py-24 md:py-32">
        <div className="mx-auto max-w-[820px] px-6 text-center">
          <Reveal>
            <p className="eyebrow">Download</p>
            <h2 className="display mt-3 text-[40px] md:text-[56px]">Get Nest.</h2>
            <p className="mx-auto mt-5 max-w-[46ch] text-[19px] leading-relaxed text-[#6e6e73]">
              A single .dmg. Drag to Applications. Built for Apple Silicon Macs running macOS 14 or later.
            </p>
            <a className="pill mt-10" href={DMG_URL}>
              Download Nest-1.0.dmg
            </a>
            <p className="mt-4 text-[13px] text-[#86868b]">
              Served from GitHub Releases. Same file every time.{" "}
              <a className="text-[#0071e3]" href={RELEASES_URL}>
                Past versions
              </a>
            </p>
          </Reveal>

          <ol className="mt-16 space-y-4 text-left">
            {[
              ["Open the disk image", "Double-click Nest-1.0.dmg. You’ll see Nest beside an Applications shortcut."],
              ["Drag Nest to Applications", "That’s the install. Eject the disk image when you’re done."],
              [
                "Open it the first time",
                "This build isn’t notarized (no paid Apple Developer certificate). Right-click Nest in Applications, choose Open, then confirm Open. You only do this once.",
              ],
              [
                "Pick a folder",
                "Downloads is the default. Any folder works. Nest classifies what’s already there, then watches for new files.",
              ],
              [
                "Decide on AI",
                "Say yes and Nest can install or start Ollama and pull a small local model for you. Say no and everything still works with on-device rules.",
              ],
            ].map(([t, d], i) => (
              <li key={t} className="flex gap-5 rounded-[24px] bg-[#f5f5f7] p-6 md:p-8">
                <span className="text-[13px] font-semibold text-[#86868b]">{String(i + 1).padStart(2, "0")}</span>
                <div>
                  <h3 className="text-[19px] font-semibold tracking-tight">{t}</h3>
                  <p className="mt-2 text-[15px] leading-relaxed text-[#6e6e73]">{d}</p>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className="faq bg-[#f5f5f7] py-24">
        <div className="mx-auto max-w-[820px] px-6">
          <h2 className="display text-[36px] md:text-[44px]">Questions, answered.</h2>
          {[
            [
              "Does Nest move my files by itself?",
              "No. It classifies in the background. Organization happens in Rules when you review groups and apply. Every move is logged and can be undone.",
            ],
            [
              "Do I need the internet or an account?",
              "No account. No Nest servers. Local classification and search work offline. Optional AI needs Ollama running locally. Optional voice uses on-device recognition.",
            ],
            [
              "Why does macOS warn me on first open?",
              "The current download isn’t notarized. That’s a signing cost, not a sandbox bypass. Right-click → Open → Open once. After that, Nest launches normally.",
            ],
            [
              "What Mac do I need?",
              "Apple Silicon (M1 or later) and macOS 14 Sonoma or later. Intel Macs are not in this build.",
            ],
            [
              "Can I use Nest without AI or a microphone?",
              "Yes. AI and Talk to Nest are off until you enable them in Settings. The watcher, categories, search, duplicates, and Expiry Center still run.",
            ],
          ].map(([q, a]) => (
            <details key={q} className="py-5">
              <summary className="flex items-center justify-between gap-6 text-[19px] font-semibold tracking-tight">
                {q}
                <span className="text-[#86868b]">+</span>
              </summary>
              <p className="mt-3 max-w-[60ch] text-[16px] leading-relaxed text-[#6e6e73]">{a}</p>
            </details>
          ))}
        </div>
      </section>

      <footer className="border-t border-black/5 bg-[#f5f5f7] py-12">
        <div className="mx-auto flex max-w-[980px] flex-col gap-8 px-6 md:flex-row md:items-center md:justify-between">
          <div className="flex items-center gap-2 text-[13px] font-semibold">
            <Logo />
            Nest
          </div>
          <div className="flex flex-wrap gap-6 text-[13px] text-[#6e6e73]">
            <a className="hover:text-black" href={DMG_URL}>
              Download
            </a>
            <a className="hover:text-black" href={GITHUB_URL}>
              GitHub
            </a>
            <a className="hover:text-black" href="#privacy">
              Privacy
            </a>
            <a className="hover:text-black" href="#install">
              Install
            </a>
          </div>
          <p className="text-[12px] text-[#86868b]">Runs on your Mac. Stays on your Mac.</p>
        </div>
      </footer>
    </div>
  );
}

function FeatureCard({ n, title, body }: { n: string; title: string; body: string }) {
  return (
    <article className="h-full rounded-[28px] bg-white p-8 shadow-[0_1px_2px_rgba(0,0,0,0.04)]">
      <p className="text-[13px] font-semibold text-[#0071e3]">{n}</p>
      <h3 className="mt-4 text-[22px] font-semibold tracking-tight">{title}</h3>
      <p className="mt-3 text-[15px] leading-relaxed text-[#6e6e73]">{body}</p>
    </article>
  );
}

function Spec({ title, body }: { title: string; body: string }) {
  return (
    <article className="rounded-[28px] bg-white p-8 md:p-10">
      <h3 className="text-[22px] font-semibold tracking-tight">{title}</h3>
      <p className="mt-3 text-[16px] leading-relaxed text-[#6e6e73]">{body}</p>
    </article>
  );
}

function QuoteStack() {
  const qs = [
    "invoice from Amazon last month",
    "what expires this month",
    "receipts over ₹5,000",
    "the presentation from yesterday",
    "show me insurance documents",
  ];
  return (
    <div className="space-y-3">
      {qs.map((q, i) => (
        <div
          key={q}
          className="rounded-full bg-white px-6 py-4 text-[16px] shadow-[0_8px_30px_rgba(0,0,0,0.04)]"
          style={{ transform: `translateX(${i % 2 === 0 ? 0 : 18}px)` }}
        >
          “{q}”
        </div>
      ))}
    </div>
  );
}

function HeroWindow() {
  return (
    <div className="overflow-hidden rounded-[22px] mac-chrome md:rounded-[32px]">
      <div className="flex items-center gap-2 px-4 py-3 md:px-5">
        <span className="dot traffic-red" />
        <span className="dot traffic-yellow" />
        <span className="dot traffic-green" />
        <span className="ml-2 text-[12px] text-[#6e6e73]">Nest</span>
      </div>
      <div className="grid bg-white md:grid-cols-[220px_1fr]">
        <div className="hidden border-r border-black/5 bg-[#f6f6f8] p-5 md:block">
          <p className="mb-3 text-[11px] font-semibold uppercase tracking-[0.14em] text-[#86868b]">Library</p>
          {["Overview", "All Files", "Categories", "Expiry Center", "Search"].map((item, i) => (
            <div
              key={item}
              className={`rounded-lg px-3 py-2 text-[13px] ${i === 0 ? "bg-[#0071e3] text-white" : "text-[#3a3a3c]"}`}
            >
              {item}
            </div>
          ))}
        </div>
        <div className="p-6 md:p-10">
          <p className="text-[13px] text-[#86868b]">Overview</p>
          <h3 className="mt-1 text-[28px] font-semibold tracking-tight">Downloads, in focus.</h3>
          <div className="mt-8 grid grid-cols-3 gap-3">
            {[
              ["128", "Files known"],
              ["9", "Need review"],
              ["4", "Dates soon"],
            ].map(([n, l]) => (
              <div key={l} className="rounded-2xl bg-[#f5f5f7] p-4 md:p-5">
                <div className="text-[26px] font-semibold tracking-tight md:text-[32px]">{n}</div>
                <div className="mt-1 text-[11px] text-[#6e6e73] md:text-[13px]">{l}</div>
              </div>
            ))}
          </div>
          <div className="mt-6 overflow-hidden rounded-2xl border border-black/5">
            {[
              ["Q2_Board_Deck.pdf", "Work · Presentation"],
              ["Emirates_BoardingPass.pdf", "Travel · Event date"],
              ["HDFC_Statement_Aug.pdf", "Finance · Statement"],
            ].map(([n, m]) => (
              <div key={n} className="flex items-center justify-between border-b border-black/5 px-4 py-3 last:border-0">
                <span className="text-[14px]">{n}</span>
                <span className="text-[12px] text-[#6e6e73]">{m}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function FloatingChip({
  className,
  title,
  sub,
}: {
  className: string;
  title: string;
  sub: string;
}) {
  return (
    <div className={`absolute rounded-2xl bg-white/90 px-4 py-3 shadow-xl shadow-black/10 backdrop-blur ${className}`}>
      <div className="text-[13px] font-semibold">{title}</div>
      <div className="text-[12px] text-[#6e6e73]">{sub}</div>
    </div>
  );
}
