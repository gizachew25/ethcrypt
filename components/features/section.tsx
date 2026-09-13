import { cn } from "@/lib/utils";

export function Section({
  title,
  subtitle,
  children,
  className
}: {
  title?: string;
  subtitle?: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <section className={cn("container py-16", className)}>
      {title && <h2 className="font-display text-3xl font-bold md:text-4xl">{title}</h2>}
      {subtitle && <p className="mt-2 max-w-2xl text-muted-foreground">{subtitle}</p>}
      <div className={cn(title && "mt-8")}>{children}</div>
    </section>
  );
}
