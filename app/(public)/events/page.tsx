import { prisma } from "@/lib/prisma";
import { Section } from "@/components/features/section";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { formatDate } from "@/lib/utils";

export const metadata = { title: "Events" };
export const dynamic = "force-dynamic";

export default async function EventsPage() {
  const events = await prisma.event.findMany({
    orderBy: { year: "desc" },
    include: { _count: { select: { challenges: true, teams: true } } }
  });

  return (
    <Section title="Events" subtitle="Past and upcoming EthCrypt symposiums.">
      {events.length === 0 ? (
        <p className="text-muted-foreground">No events published yet.</p>
      ) : (
        <div className="grid gap-6 md:grid-cols-2">
          {events.map((e) => (
            <Card key={e.id}>
              <CardContent className="p-6">
                <div className="mb-2 flex items-center justify-between">
                  <h3 className="font-display text-xl font-semibold">{e.title}</h3>
                  {e.isCurrent && <Badge variant="accent">Current</Badge>}
                </div>
                <p className="text-sm text-muted-foreground">{e.description}</p>
                <div className="mt-4 flex flex-wrap gap-4 text-sm text-muted-foreground">
                  <span>{formatDate(e.startsAt)}</span>
                  <span>{e.location}</span>
                  <span>{e._count.challenges} challenges</span>
                  <span>{e._count.teams} teams</span>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </Section>
  );
}
