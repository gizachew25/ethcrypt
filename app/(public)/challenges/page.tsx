import { prisma } from "@/lib/prisma";
import { getCurrentUser } from "@/lib/session";
import Link from "next/link";
import { Lock, Flag } from "lucide-react";
import { Section } from "@/components/features/section";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

export const metadata = { title: "Challenges" };
export const dynamic = "force-dynamic";

export default async function ChallengesPage() {
  const user = await getCurrentUser();
  const event = await prisma.event.findFirst({ where: { isCurrent: true } });
  const challenges = event
    ? await prisma.challenge.findMany({
        where: { eventId: event.id, published: true },
        orderBy: [{ category: "asc" }, { points: "asc" }],
        include: { _count: { select: { solves: true } } }
      })
    : [];

  return (
    <Section
      title="Challenges"
      subtitle={user ? "Solve challenges from your dashboard." : "Register to unlock full briefs and submit flags."}
    >
      {challenges.length === 0 ? (
        <p className="text-muted-foreground">Challenges will be published when the event opens.</p>
      ) : (
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {challenges.map((c) => (
            <Card key={c.id}>
              <CardContent className="p-6">
                <div className="mb-3 flex items-center justify-between">
                  <Badge>{c.category}</Badge>
                  <span className="font-display font-bold text-accent">{c.points} pts</span>
                </div>
                <h3 className="mb-2 font-semibold">{c.title}</h3>
                {user ? (
                  <p className="line-clamp-2 text-sm text-muted-foreground">{c.description}</p>
                ) : (
                  <p className="flex items-center gap-1 text-sm text-muted-foreground">
                    <Lock className="h-3 w-3" /> Register to view the full brief
                  </p>
                )}
                <div className="mt-4 flex items-center justify-between">
                  <span className="flex items-center gap-1 text-xs text-muted-foreground">
                    <Flag className="h-3 w-3" /> {c._count.solves} solves
                  </span>
                  {user ? (
                    <Link href="/dashboard"><Button size="sm" variant="outline">Solve</Button></Link>
                  ) : (
                    <Link href="/register"><Button size="sm" variant="accent">Unlock</Button></Link>
                  )}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </Section>
  );
}
