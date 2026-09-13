import Link from "next/link";
import { Shield, Flag, Trophy, Users, ArrowRight, Calendar } from "lucide-react";
import { prisma } from "@/lib/prisma";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Countdown } from "@/components/features/countdown";
import { Section } from "@/components/features/section";
import { formatDate } from "@/lib/utils";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const event = await prisma.event.findFirst({
    where: { isCurrent: true },
    include: { _count: { select: { challenges: true, teams: true } } }
  });
  const sponsors = await prisma.sponsor.findMany({ orderBy: { tier: "asc" }, take: 8 });

  const stats = [
    { icon: Flag, label: "Challenges", value: event?._count.challenges ?? 0 },
    { icon: Users, label: "Teams", value: event?._count.teams ?? 0 },
    { icon: Trophy, label: "Categories", value: 6 }
  ];

  return (
    <>
      <section className="relative overflow-hidden border-b">
        <div className="absolute inset-0 -z-10 bg-[radial-gradient(60%_50%_at_50%_0%,hsl(var(--accent)/0.18),transparent)]" />
        <div className="container grid gap-12 py-20 lg:grid-cols-2 lg:py-28">
          <div className="animate-fade-up">
            <Badge variant="accent" className="mb-4">
              <Shield className="mr-1 h-3 w-3" /> Hosted by Dire Dawa University
            </Badge>
            <h1 className="font-display text-4xl font-bold leading-tight md:text-6xl">
              The Ethiopian Cyber Security Challenge
            </h1>
            <p className="mt-6 max-w-xl text-lg text-muted-foreground">
              EthCrypt brings students, researchers and industry together for a national
              symposium and capture-the-flag competition. Build skills, solve real challenges,
              and represent your team.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link href="/register">
                <Button variant="accent" size="lg">
                  Register your team <ArrowRight className="h-4 w-4" />
                </Button>
              </Link>
              <Link href="/challenges">
                <Button variant="outline" size="lg">View challenges</Button>
              </Link>
            </div>
            <div className="mt-10 grid max-w-md grid-cols-3 gap-4">
              {stats.map((s) => (
                <div key={s.label}>
                  <div className="flex items-center gap-2 text-accent">
                    <s.icon className="h-4 w-4" />
                    <span className="font-display text-2xl font-bold">{s.value}</span>
                  </div>
                  <p className="text-xs text-muted-foreground">{s.label}</p>
                </div>
              ))}
            </div>
          </div>

          <div className="flex flex-col justify-center">
            {event ? (
              <Card className="animate-fade-up">
                <CardContent className="p-6">
                  <div className="mb-4 flex items-center gap-2 text-sm text-muted-foreground">
                    <Calendar className="h-4 w-4" />
                    {event.title} · {formatDate(event.startsAt)}
                  </div>
                  <h3 className="mb-4 font-display text-xl font-semibold">Competition starts in</h3>
                  <Countdown target={event.startsAt.toISOString()} />
                  <p className="mt-4 text-sm text-muted-foreground">{event.location}</p>
                </CardContent>
              </Card>
            ) : (
              <Card>
                <CardContent className="p-6 text-muted-foreground">
                  The next symposium will be announced soon.
                </CardContent>
              </Card>
            )}
          </div>
        </div>
      </section>

      <Section title="Why compete" subtitle="A national platform to test and grow your cybersecurity skills.">
        <div className="grid gap-6 md:grid-cols-3">
          {[
            { icon: Flag, title: "Real-world challenges", body: "Web, crypto, forensics, pwn, reversing and OSINT — designed by practitioners." },
            { icon: Trophy, title: "Live leaderboard", body: "Track your team's rank as solves land, with a public read-only board." },
            { icon: Users, title: "Community", body: "Meet students, judges and industry mentors from across the country." }
          ].map((f) => (
            <Card key={f.title}>
              <CardContent className="p-6">
                <f.icon className="mb-3 h-6 w-6 text-accent" />
                <h3 className="mb-2 font-semibold">{f.title}</h3>
                <p className="text-sm text-muted-foreground">{f.body}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </Section>

      {sponsors.length > 0 && (
        <Section title="Sponsors & partners">
          <div className="flex flex-wrap items-center gap-4">
            {sponsors.map((s) => (
              <div key={s.id} className="rounded-lg border bg-card px-6 py-4 text-sm font-medium">
                {s.name}
              </div>
            ))}
          </div>
        </Section>
      )}

      <section className="border-t bg-primary text-primary-foreground">
        <div className="container flex flex-col items-center gap-6 py-16 text-center">
          <h2 className="font-display text-3xl font-bold md:text-4xl">Ready to join EthCrypt?</h2>
          <p className="max-w-xl text-primary-foreground/80">
            Create your account, form a team, and start solving.
          </p>
          <Link href="/register">
            <Button variant="accent" size="lg">Get started <ArrowRight className="h-4 w-4" /></Button>
          </Link>
        </div>
      </section>
    </>
  );
}
