import { prisma } from "@/lib/prisma";
import { Section } from "@/components/features/section";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export const metadata = { title: "Sponsors & Partners" };
export const dynamic = "force-dynamic";

export default async function SponsorsPage() {
  const sponsors = await prisma.sponsor.findMany({ orderBy: { tier: "asc" } });
  const tiers = ["PLATINUM", "GOLD", "SILVER", "PARTNER"] as const;

  return (
    <Section title="Sponsors & partners" subtitle="EthCrypt is made possible by our supporters.">
      {tiers.map((tier) => {
        const list = sponsors.filter((s) => s.tier === tier);
        if (list.length === 0) return null;
        return (
          <div key={tier} className="mb-8">
            <h3 className="mb-3 text-sm font-semibold uppercase tracking-wide text-muted-foreground">
              {tier}
            </h3>
            <div className="grid gap-4 sm:grid-cols-2 md:grid-cols-4">
              {list.map((s) => (
                <Card key={s.id}>
                  <CardContent className="flex flex-col items-center gap-2 p-6 text-center">
                    <span className="font-semibold">{s.name}</span>
                    <Badge>{s.tier}</Badge>
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        );
      })}
    </Section>
  );
}
