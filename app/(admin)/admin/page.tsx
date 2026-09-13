import { prisma } from "@/lib/prisma";
import { computeLeaderboard } from "@/lib/scoring";
import { Card, CardContent } from "@/components/ui/card";
import { LeaderboardTable } from "@/components/features/leaderboard-table";
import { Users, Flag, Calendar, MessageSquare, Megaphone, ShieldCheck } from "lucide-react";

export const dynamic = "force-dynamic";

export default async function AdminPage() {
  const [users, teams, challenges, events, contacts, announcements] = await Promise.all([
    prisma.user.count(),
    prisma.team.count(),
    prisma.challenge.count(),
    prisma.event.count(),
    prisma.contactMessage.count({ where: { handled: false } }),
    prisma.announcement.count()
  ]);
  const board = await computeLeaderboard();

  const recentContacts = await prisma.contactMessage.findMany({
    orderBy: { createdAt: "desc" },
    take: 5
  });

  const cards = [
    { icon: Users, label: "Users", value: users },
    { icon: ShieldCheck, label: "Teams", value: teams },
    { icon: Flag, label: "Challenges", value: challenges },
    { icon: Calendar, label: "Events", value: events },
    { icon: Megaphone, label: "Announcements", value: announcements },
    { icon: MessageSquare, label: "New messages", value: contacts }
  ];

  return (
    <div className="space-y-8">
      <div>
        <h1 className="font-display text-3xl font-bold">Admin console</h1>
        <p className="text-muted-foreground">Overview of the current event.</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {cards.map((c) => (
          <Card key={c.label}>
            <CardContent className="flex items-center gap-4 p-6">
              <c.icon className="h-7 w-7 text-accent" />
              <div>
                <div className="font-display text-2xl font-bold">{c.value}</div>
                <div className="text-sm text-muted-foreground">{c.label}</div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      <div>
        <h2 className="mb-4 font-display text-2xl font-bold">Leaderboard</h2>
        <LeaderboardTable rows={board} />
      </div>

      <div>
        <h2 className="mb-4 font-display text-2xl font-bold">Recent contact messages</h2>
        {recentContacts.length === 0 ? (
          <p className="text-muted-foreground">No messages yet.</p>
        ) : (
          <div className="space-y-3">
            {recentContacts.map((m) => (
              <Card key={m.id}>
                <CardContent className="p-4">
                  <div className="flex items-center justify-between">
                    <span className="font-medium">{m.subject}</span>
                    <span className="text-xs text-muted-foreground">{m.email}</span>
                  </div>
                  <p className="mt-1 text-sm text-muted-foreground">{m.message}</p>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
