import { LifePhoto } from "@/components/LifePhoto";
import { Reveal } from "@/components/Reveal";
import { lifeScenes } from "@/lib/lifeScenes";

export function PeopleStoriesIntro() {
  return (
    <section className="bg-[#1d1d1f] py-20 md:py-28">
      <div className="mx-auto max-w-[980px] px-6 text-center">
        <Reveal>
          <p className="text-[12px] font-semibold tracking-[0.16em] text-[#86868b] uppercase">Real life, real folders</p>
          <h2 className="display mt-4 text-[36px] text-white md:text-[52px]">
            Built for the way India actually downloads.
          </h2>
          <p className="mx-auto mt-5 max-w-[52ch] text-[18px] leading-relaxed text-[#a1a1a6]">
            Invoices, admit cards, Aadhaar scans, lecture decks, boarding passes — Nest meets people where the files
            already are. On your Mac. In your language. With your consent.
          </p>
        </Reveal>
      </div>
      <div className="mx-auto mt-14 max-w-[1200px] px-6">
        <Reveal delay={80}>
          <LifePhoto
            src={lifeScenes[0].src}
            alt={lifeScenes[0].alt}
            caption={lifeScenes[0].caption}
            task={lifeScenes[0].task}
            priority
            className="w-full"
            sizes="100vw"
            aspect="wide"
          />
        </Reveal>
      </div>
    </section>
  );
}

export function PeopleStoryBand({
  sceneIndex,
  reverse = false,
  kicker,
  title,
  body,
}: {
  sceneIndex: number;
  reverse?: boolean;
  kicker: string;
  title: string;
  body: string;
}) {
  const scene = lifeScenes[sceneIndex];
  return (
    <section className="py-20 md:py-28">
      <div
        className={`mx-auto grid max-w-[980px] items-center gap-12 px-6 md:grid-cols-2 md:gap-16 ${reverse ? "md:[&>*:first-child]:order-2" : ""}`}
      >
        <Reveal>
          <p className="eyebrow">{kicker}</p>
          <h2 className="display mt-3 text-[32px] md:text-[44px]">{title}</h2>
          <p className="mt-5 text-[18px] leading-relaxed text-[#6e6e73]">{body}</p>
        </Reveal>
        <Reveal delay={100}>
          <LifePhoto
            src={scene.src}
            alt={scene.alt}
            caption={scene.caption}
            task={scene.task}
            sizes="(max-width: 768px) 100vw, 480px"
            aspect={sceneIndex === 3 || sceneIndex === 4 ? "portrait" : "landscape"}
          />
        </Reveal>
      </div>
    </section>
  );
}

export function PeopleMosaic() {
  const mosaic = [lifeScenes[4], lifeScenes[1], lifeScenes[3], lifeScenes[5]];
  return (
    <section className="bg-[#f5f5f7] py-20 md:py-28">
      <div className="mx-auto max-w-[980px] px-6">
        <Reveal>
          <p className="eyebrow">Inclusive by design</p>
          <h2 className="display mt-3 max-w-[20ch] text-[36px] md:text-[48px]">
            Students, freelancers, families — same quiet helper.
          </h2>
          <p className="mt-5 max-w-[50ch] text-[18px] leading-relaxed text-[#6e6e73]">
            Gender-diverse, age-diverse, city-diverse. Nest doesn’t judge the pile; it reads what’s inside and waits for
            you to decide what happens next.
          </p>
        </Reveal>
        <div className="mt-14 grid gap-4 md:grid-cols-2">
          {mosaic.map((scene, i) => (
            <Reveal key={scene.src} delay={i * 60}>
              <LifePhoto
                src={scene.src}
                alt={scene.alt}
                caption={scene.caption}
                task={scene.task}
                className={i === 3 ? "md:col-span-2" : ""}
                sizes={i === 3 ? "100vw" : "(max-width: 768px) 100vw, 480px"}
                aspect={i === 2 ? "portrait" : i === 3 ? "wide" : "landscape"}
              />
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

export function PeoplePrivacyStrip() {
  const scene = lifeScenes[2];
  return (
    <div className="mx-auto mt-14 max-w-[980px] px-6">
      <Reveal>
        <LifePhoto
          src={scene.src}
          alt={scene.alt}
          caption={scene.caption}
          task="Important dates stay on your Mac — reviewed by you, not uploaded to a server."
          sizes="100vw"
        />
      </Reveal>
    </div>
  );
}
