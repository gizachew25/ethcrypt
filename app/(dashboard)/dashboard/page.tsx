import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/session";
import { prisma } from "@/lib/prisma";
import { computeLeaderboard } from "@/lib/scoring";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { FlagForm } from "@/components/features/flag-form";
import { TeamPanel } from "@/components/features/team-panel";
import { Trophy, Users, Flag } from "lucide-react";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const user = await getCurrentUser();
  if (!user) redirect("/login");

  const dbUser = await prisma.user.findUnique({
    where: { id: user.id },
    include: { team: true }
  });

  const event = await prisma.event.findFirst({ where: { isCurrent: true } });
  const challenges = event
    ? await prisma.challenge.findMany({
        where: { eventId: event.id, published: true },
        orderBy: [{ category: "asc" }, { points: "asc" }]
      })
    : [];

  const solves = dbUser?.teamId
    ? await prisma.solve.findMany({ where: { teamId: dbUser.teamId }, select: { challengeId: true } })
    : [];
  const solvedIds = new Set(solves.map((s) => s.challengeId));

  const board = await computeLeaderboard();
  const myRow = dbUser?.teamId ? board.find((r) => r.teamId === dbUser.teamId) : undefined;

  const stats = [
    { icon: Trophy, label: "Rank", value: myRow ? `#${myRow.rank}` : "—" },
    { icon: Flag, label: "Score", value: myRow?.score ?? 0 },
    { icon: Users, label: "Solves", value: myRow?.solves ?? 0 }
  ];

  return (
    <div className="space-y-8">
      <div>
        <h1 className="font-display text-3xl font-bold">Welcome, {user.name}</h1>
        <p className="text-muted-foreground">{event ? event.title : "No active event"}</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        {stats.map((s) => (
          <Card key={s.label}>
            <CardContent className="flex items-center gap-4 p-6">
              <s.icon className="h-8 w-8 text-accent" />
              <div>
                <div className="font-display text-2xl font-bold">{s.value}</div>
                <div className="text-sm text-muted-foreground">{s.label}</div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      <TeamPanel team={dbUser?.team ?? null} />

      <div>
        <h2 className="mb-4 font-display text-2xl font-bold">Challenges</h2>
        {!dbUser?.teamId && (
          <p className="mb-4 text-sm text-muted-foreground">
            Join or create a team above to have your solves counted on the leaderboard.
          </p>
        )}
        {challenges.length === 0 ? (
          <p className="text-muted-foreground">No published challenges yet.</p>
        ) : (
          <div className="grid gap-4 md:grid-cols-2">
            {challenges.map((c) => (
              <Card key={c.id}>
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <CardTitle className="text-base">{c.title}</CardTitle>
                    <Badge>{c.category}</Badge>
                  </div>
                </CardHeader>
                <CardContent className="space-y-3">
                  <p className="text-sm text-muted-foreground">{c.description}</p>
                  <p className="text-sm font-semibold text-accent">{c.points} points</p>
                  <FlagForm challengeId={c.id} solved={solvedIds.has(c.id)} />
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
