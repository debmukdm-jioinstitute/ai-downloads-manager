import Image from "next/image";

type LifePhotoProps = {
  src: string;
  alt: string;
  caption?: string;
  task?: string;
  priority?: boolean;
  className?: string;
  sizes?: string;
  aspect?: "landscape" | "portrait" | "wide";
};

export function LifePhoto({
  src,
  alt,
  caption,
  task,
  priority = false,
  className = "",
  sizes = "(max-width: 768px) 100vw, 50vw",
  aspect = "landscape",
}: LifePhotoProps) {
  const frameClass =
    aspect === "portrait" ? "life-photo-frame portrait" : aspect === "wide" ? "life-photo-frame wide" : "life-photo-frame";

  return (
    <figure className={`life-photo group ${className}`}>
      <div className={frameClass}>
        <Image
          src={src}
          alt={alt}
          fill
          priority={priority}
          sizes={sizes}
          className="object-cover transition duration-700 group-hover:scale-[1.02]"
        />
        {(caption || task) && (
          <figcaption className="life-photo-caption">
            {caption && <p className="text-[13px] font-semibold text-white">{caption}</p>}
            {task && <p className="mt-1 text-[14px] leading-snug text-white/85">{task}</p>}
          </figcaption>
        )}
      </div>
    </figure>
  );
}
