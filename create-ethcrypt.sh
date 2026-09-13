#!/usr/bin/env bash
#
# create-ethcrypt.sh — generates the complete EthCrypt project and zips it.
# Usage:  bash create-ethcrypt.sh    (safe to re-run; overwrites ./ethcrypt)
# Requires: bash, coreutils, and 'zip'. Tested on macOS and Linux.
#
set -euo pipefail

ROOT="ethcrypt"
echo "==> Creating EthCrypt project in ./$ROOT"
rm -rf "$ROOT"
mkdir -p "$ROOT"

write() {
  # write <relative-path>  (content follows on stdin until the heredoc marker)
  local target="$ROOT/$1"
  mkdir -p "$(dirname "$target")"
  cat > "$target"
}

write '.env.example' <<'ETHCRYPT_HEREDOC_EOF'
# ---- Database (Render-managed Postgres) ----
DATABASE_URL=postgresql://user:password@localhost:5432/ethcrypt?schema=public

# ---- NextAuth ----
NEXTAUTH_SECRET=replace-with-openssl-rand-base64-32
NEXTAUTH_URL=http://localhost:3000
NEXT_PUBLIC_APP_URL=http://localhost:3000

# ---- Email (Resend). Leave RESEND_API_KEY empty to log emails to console instead. ----
RESEND_API_KEY=
EMAIL_FROM=EthCrypt <no-reply@ethcrypt.ddu.edu.et>

# ---- File uploads (Cloudinary, optional) ----
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=

# ---- Google OAuth (optional) ----
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

# ---- Seed admin (used by prisma/seed.ts) ----
ADMIN_EMAIL=admin@ethcrypt.ddu.edu.et
ADMIN_PASSWORD=ChangeMe123!
ETHCRYPT_HEREDOC_EOF

write '.eslintrc.json' <<'ETHCRYPT_HEREDOC_EOF'
{ "extends": "next/core-web-vitals" }
ETHCRYPT_HEREDOC_EOF

write '.gitignore' <<'ETHCRYPT_HEREDOC_EOF'
node_modules
.next
out
.env
.env*.local
*.log
.DS_Store
/prisma/dev.db
ethcrypt.zip
.vercel
ETHCRYPT_HEREDOC_EOF

write 'DEPLOYMENT.md' <<'ETHCRYPT_HEREDOC_EOF'
# Deploying EthCrypt to Render

Two paths: **Blueprint** (recommended, one click) or **manual**.

## Option A — Blueprint (render.yaml)
1. Push this repository to GitHub/GitLab.
2. In Render: **New → Blueprint**, select the repo. Render reads `render.yaml`
   and provisions:
   - `ethcrypt-db` (managed PostgreSQL)
   - `ethcrypt-web` (Node web service)
3. When prompted, set the `sync: false` env vars:
   - `NEXTAUTH_URL` = your web URL, e.g. `https://ethcrypt-web.onrender.com`
   - `NEXT_PUBLIC_APP_URL` = same URL
   - `ADMIN_PASSWORD` = a strong password
   - Optional: `RESEND_API_KEY`, `CLOUDINARY_*`
   `NEXTAUTH_SECRET` and `DATABASE_URL` are generated/wired automatically.
4. Click **Apply**. The build runs:
   `npm install && npx prisma generate && npx prisma db push --accept-data-loss && npm run build`
5. After first deploy, seed demo data from the service **Shell**:
   ```bash
   npm run db:seed
   ```
6. Health check: Render polls `/api/health`. Visit `/` to confirm.

## Option B — Manual
1. **New → PostgreSQL** → create `ethcrypt-db`. Copy the Internal Database URL.
2. **New → Web Service** → connect the repo, runtime **Node**.
   - Build command:
     `npm install && npx prisma generate && npx prisma db push --accept-data-loss && npm run build`
   - Start command: `npm start`
   - Health check path: `/api/health`
3. Add environment variables (see `.env.example`):
   `DATABASE_URL`, `NEXTAUTH_SECRET` (`openssl rand -base64 32`), `NEXTAUTH_URL`,
   `NEXT_PUBLIC_APP_URL`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`, and any optional keys.
4. Deploy, then run `npm run db:seed` in the Shell.

## Schema & migrations
The default build uses `prisma db push`, which creates the schema directly from
`prisma/schema.prisma` on the fresh Render database — no committed migration
files required, so first deploy always succeeds. This is ideal for demo and
early production.

To move to versioned migrations (recommended once the schema stabilises):
```bash
npx prisma migrate dev --name init        # locally, generates prisma/migrations
```
Commit the generated migration, then change the Render build step to
`... && npx prisma migrate deploy && ...`.

## Prisma on Render
`schema.prisma` sets `binaryTargets = ["native", "debian-openssl-3.0.x", "debian-openssl-1.1.x"]`
and `package.json` has a `postinstall: prisma generate`, so the correct engine is
available in Render's build image.

## Notes / extension points
- **Email**: without `RESEND_API_KEY`, `lib/mail.ts` logs to the console — safe for
  first deploy. Add the key to send real mail.
- **Uploads**: `CLOUDINARY_*` env vars are wired in `.env.example`; add an upload
  route under `app/api/uploads` to use them.
- **Cron scoring**: add a Render Cron Job hitting an internal endpoint if you move
  from static to dynamic scoring.
- **Admin CRUD / CSV-PDF / certificates / i18n**: the data model supports these;
  build screens under `app/(admin)/admin/*` and routes under `app/api/*`.
ETHCRYPT_HEREDOC_EOF

write 'Dockerfile' <<'ETHCRYPT_HEREDOC_EOF'
# Optional Dockerfile for Render (Docker runtime). The Node runtime + render.yaml
# is the recommended path; this is provided for parity.
FROM node:20-slim AS base
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*
WORKDIR /app

FROM base AS deps
COPY package.json package-lock.json* ./
COPY prisma ./prisma
RUN npm install

FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npx prisma generate && npm run build

FROM base AS runner
ENV NODE_ENV=production
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/public ./public
COPY --from=builder /app/prisma ./prisma
EXPOSE 3000
CMD ["npm", "start"]
ETHCRYPT_HEREDOC_EOF

write 'README.md' <<'ETHCRYPT_HEREDOC_EOF'
# EthCrypt — Ethiopian Cyber Security Challenge

A Next.js 14 (App Router) + TypeScript + Prisma + PostgreSQL platform for the
Ethiopian Cyber Security Challenge, hosted by Dire Dawa University. Public site,
participant CTF workspace, and an admin/judge console.

## Stack
- Next.js 14 App Router, React Server Components, TypeScript
- Tailwind CSS with dark/light mode (dark default), shadcn-style UI, Lucide icons
- Prisma ORM + PostgreSQL
- NextAuth (credentials, optional Google) with roles: ADMIN, JUDGE, PARTICIPANT, GUEST
- Zod validation, in-memory rate limiting, audit log
- TanStack Query on the client where needed
- Resend email (falls back to console logging without an API key)

## Quick start (local)
```bash
cp .env.example .env            # fill in DATABASE_URL + NEXTAUTH_SECRET
npm install
npx prisma db push                   # or: npx prisma migrate dev --name init
npm run db:seed
npm run dev
```
Open http://localhost:3000.

Generate a secret with: `openssl rand -base64 32`

## Demo logins (after seeding)
- Admin: `admin@ethcrypt.ddu.edu.et` / `ChangeMe123!` (from ADMIN_* env)
- Judge: `judge1@ethcrypt.ddu.edu.et` / `Password123!`
- Participant: `user1@student.ddu.edu.et` / `Password123!`

## Scripts
- `npm run dev` — start the dev server
- `npm run build` — prisma generate + next build
- `npm start` — production server
- `npm run db:migrate` — create/apply a dev migration
- `npm run db:deploy` — apply migrations (production)
- `npm run db:seed` — seed demo data
- `npm run db:reset` — reset and reseed (destructive)

## Project layout
See the file tree in DEPLOYMENT.md. The Prisma schema in `prisma/schema.prisma`
models the entire platform (events, teams, challenges, hints, submissions,
solves, score adjustments, announcements, news, sponsors, gallery, contact,
certificates, audit log) even where a given admin screen is not yet built out.

## What is implemented vs. scaffolded
Implemented end-to-end: auth + roles, registration, team create/join, challenge
listing, flag submission with first-blood solve scoring, live leaderboard
(public + admin), contact form (DB + email), announcements/news/sponsors/events
pages, health check, SEO (sitemap/robots/OG), rate limiting, audit logging.

Scaffolded via the data model + admin overview, ready to extend: full admin CRUD
screens for challenges/users/teams, CSV/PDF export, certificate PDF generation,
Cloudinary uploads, Amharic i18n, and gallery management. Extension points are
noted in `DEPLOYMENT.md`.

© Dire Dawa University.
ETHCRYPT_HEREDOC_EOF

write 'app/(admin)/admin/page.tsx' <<'ETHCRYPT_HEREDOC_EOF'
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
ETHCRYPT_HEREDOC_EOF

write 'app/(admin)/layout.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import { redirect } from "next/navigation";
import { requireRole } from "@/lib/session";
import { Navbar } from "@/components/layout/navbar";

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const user = await requireRole("ADMIN", "JUDGE");
  if (!user) redirect("/dashboard");
  return (
    <div className="flex min-h-screen flex-col">
      <Navbar />
      <main className="container flex-1 py-10">{children}</main>
    </div>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'app/(auth)/layout.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import Link from "next/link";
import { Shield } from "lucide-react";

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-background px-6">
      <Link href="/" className="mb-8 flex items-center gap-2 font-display text-2xl font-bold">
        <Shield className="h-7 w-7 text-accent" /> EthCrypt
      </Link>
      <div className="w-full max-w-md">{children}</div>
    </div>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'app/(auth)/login/page.tsx' <<'ETHCRYPT_HEREDOC_EOF'
"use client";

import { useState } from "react";
import { signIn } from "next-auth/react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export default function LoginPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const form = new FormData(e.currentTarget);
    const res = await signIn("credentials", {
      email: String(form.get("email")),
      password: String(form.get("password")),
      redirect: false
    });
    setLoading(false);
    if (res?.error) setError("Invalid email or password.");
    else router.push("/dashboard");
  }

  return (
    <Card>
      <CardHeader><CardTitle>Log in</CardTitle></CardHeader>
      <CardContent>
        <form onSubmit={onSubmit} className="space-y-4">
          <Input name="email" type="email" placeholder="Email" required />
          <Input name="password" type="password" placeholder="Password" required />
          {error && <p className="text-sm text-destructive">{error}</p>}
          <Button type="submit" variant="accent" className="w-full" disabled={loading}>
            {loading ? "Signing in…" : "Log in"}
          </Button>
        </form>
        <p className="mt-4 text-center text-sm text-muted-foreground">
          No account? <Link href="/register" className="text-accent hover:underline">Register</Link>
        </p>
      </CardContent>
    </Card>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'app/(auth)/register/page.tsx' <<'ETHCRYPT_HEREDOC_EOF'
"use client";

import { useState } from "react";
import { signIn } from "next-auth/react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export default function RegisterPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const form = new FormData(e.currentTarget);
    const payload = Object.fromEntries(form.entries());

    const res = await fetch("/api/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });

    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      setError(data.error ?? "Registration failed.");
      setLoading(false);
      return;
    }

    await signIn("credentials", {
      email: String(payload.email),
      password: String(payload.password),
      redirect: false
    });
    router.push("/dashboard");
  }

  return (
    <Card>
      <CardHeader><CardTitle>Create your account</CardTitle></CardHeader>
      <CardContent>
        <form onSubmit={onSubmit} className="space-y-4">
          <Input name="name" placeholder="Full name" required minLength={2} />
          <Input name="email" type="email" placeholder="Email" required />
          <Input name="institution" placeholder="Institution (optional)" />
          <Input name="password" type="password" placeholder="Password (min 8 chars)" required minLength={8} />
          {error && <p className="text-sm text-destructive">{error}</p>}
          <Button type="submit" variant="accent" className="w-full" disabled={loading}>
            {loading ? "Creating…" : "Register"}
          </Button>
        </form>
        <p className="mt-4 text-center text-sm text-muted-foreground">
          Already have an account? <Link href="/login" className="text-accent hover:underline">Log in</Link>
        </p>
      </CardContent>
    </Card>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'app/(dashboard)/dashboard/page.tsx' <<'ETHCRYPT_HEREDOC_EOF'
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
ETHCRYPT_HEREDOC_EOF

write 'app/(dashboard)/layout.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import { Navbar } from "@/components/layout/navbar";

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col">
      <Navbar />
      <main className="container flex-1 py-10">{children}</main>
    </div>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'app/(public)/about/page.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import { Section } from "@/components/features/section";
import { Card, CardContent } from "@/components/ui/card";

export const metadata = { title: "About" };

export default function AboutPage() {
  const committee = [
    { name: "Dr. Selam Abebe", role: "Symposium Chair" },
    { name: "Yohannes Tesfaye", role: "CTF Lead" },
    { name: "DDU School of Computing", role: "Host" }
  ];
  return (
    <>
      <Section title="About EthCrypt" subtitle="Building Ethiopia's cybersecurity talent pipeline.">
        <div className="prose max-w-3xl text-muted-foreground">
          <p>
            EthCrypt is the Ethiopian Cyber Security Challenge, an annual symposium and
            capture-the-flag competition hosted by Dire Dawa University. It exists to grow
            practical security skills among students and professionals, and to connect them with
            industry and government partners.
          </p>
          <p className="mt-4">
            Since its 2024 pilot, the event has expanded into a national platform where teams
            compete across web, cryptography, forensics, binary exploitation, reverse engineering
            and OSINT.
          </p>
        </div>
      </Section>
      <Section title="Organizing committee">
        <div className="grid gap-6 md:grid-cols-3">
          {committee.map((m) => (
            <Card key={m.name}>
              <CardContent className="p-6">
                <h3 className="font-semibold">{m.name}</h3>
                <p className="text-sm text-muted-foreground">{m.role}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </Section>
    </>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'app/(public)/challenges/page.tsx' <<'ETHCRYPT_HEREDOC_EOF'
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
ETHCRYPT_HEREDOC_EOF

write 'app/(public)/contact/page.tsx' <<'ETHCRYPT_HEREDOC_EOF'
"use client";

import { useState } from "react";
import { Section } from "@/components/features/section";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Mail, MapPin } from "lucide-react";

export default function ContactPage() {
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("sending");
    setError(null);
    const form = new FormData(e.currentTarget);
    const payload = Object.fromEntries(form.entries());

    const res = await fetch("/api/contact", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });

    if (res.ok) {
      setStatus("sent");
      e.currentTarget.reset();
    } else {
      const data = await res.json().catch(() => ({}));
      setError(data.error ?? "Could not send your message. Try again.");
      setStatus("error");
    }
  }

  return (
    <Section title="Contact" subtitle="Questions about EthCrypt? Send us a message.">
      <div className="grid gap-8 lg:grid-cols-3">
        <div className="space-y-4 text-sm text-muted-foreground">
          <p className="flex items-center gap-2"><Mail className="h-4 w-4 text-accent" /> info@ethcrypt.ddu.edu.et</p>
          <p className="flex items-center gap-2"><MapPin className="h-4 w-4 text-accent" /> Dire Dawa University, Ethiopia</p>
        </div>
        <Card className="lg:col-span-2">
          <CardContent className="p-6">
            {status === "sent" ? (
              <p className="text-accent">Thanks — your message was received. We'll be in touch.</p>
            ) : (
              <form onSubmit={onSubmit} className="space-y-4">
                <div className="grid gap-4 sm:grid-cols-2">
                  <Input name="name" placeholder="Your name" required minLength={2} />
                  <Input name="email" type="email" placeholder="Email" required />
                </div>
                <Input name="subject" placeholder="Subject" required minLength={2} />
                <textarea
                  name="message"
                  placeholder="Your message"
                  required
                  minLength={10}
                  rows={5}
                  className="flex w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                />
                {error && <p className="text-sm text-destructive">{error}</p>}
                <Button type="submit" variant="accent" disabled={status === "sending"}>
                  {status === "sending" ? "Sending…" : "Send message"}
                </Button>
              </form>
            )}
          </CardContent>
        </Card>
      </div>
    </Section>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'app/(public)/events/page.tsx' <<'ETHCRYPT_HEREDOC_EOF'
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
ETHCRYPT_HEREDOC_EOF

write 'app/(public)/faq/page.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import { Section } from "@/components/features/section";
import { Card, CardContent } from "@/components/ui/card";

export const metadata = { title: "FAQ, Terms & Privacy" };

const faqs = [
  { q: "Who can participate?", a: "Students, professionals and cybersecurity enthusiasts. Teams of up to five compete in the CTF." },
  { q: "How do I register?", a: "Create an account, then create or join a team using an invite code." },
  { q: "How is scoring calculated?", a: "Static points per challenge, awarded on first correct flag per team, with manual judge adjustments where needed." },
  { q: "Is the leaderboard public?", a: "Yes, the leaderboard is read-only and public. It may be frozen near the end of the event." }
];

export default function FaqPage() {
  return (
    <>
      <Section title="Frequently asked questions">
        <div className="space-y-4">
          {faqs.map((f) => (
            <Card key={f.q}>
              <CardContent className="p-6">
                <h3 className="mb-1 font-semibold">{f.q}</h3>
                <p className="text-sm text-muted-foreground">{f.a}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </Section>
      <Section title="Terms of use" className="pt-0">
        <p id="terms" className="max-w-3xl text-sm text-muted-foreground">
          By participating you agree to compete fairly, not to attack the scoring
          infrastructure, and to follow the code of conduct. Violations may result in
          disqualification at the judges' discretion.
        </p>
      </Section>
      <Section title="Privacy policy" className="pt-0">
        <p id="privacy" className="max-w-3xl text-sm text-muted-foreground">
          We store the account and team data you provide to run the competition. Contact
          messages are stored to respond to your enquiry. We do not sell personal data.
        </p>
      </Section>
    </>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'app/(public)/layout.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import { Navbar } from "@/components/layout/navbar";
import { Footer } from "@/components/layout/footer";

export default function PublicLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col">
      <Navbar />
      <main className="flex-1">{children}</main>
      <Footer />
    </div>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'app/(public)/leaderboard/page.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import { computeLeaderboard } from "@/lib/scoring";
import { Section } from "@/components/features/section";
import { LeaderboardTable } from "@/components/features/leaderboard-table";

export const metadata = { title: "Leaderboard" };
export const dynamic = "force-dynamic";

export default async function LeaderboardPage() {
  const rows = await computeLeaderboard();
  return (
    <Section title="Leaderboard" subtitle="Live team rankings for the current event.">
      <LeaderboardTable rows={rows} />
    </Section>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'app/(public)/news/page.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import { prisma } from "@/lib/prisma";
import { Section } from "@/components/features/section";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { formatDate } from "@/lib/utils";

export const metadata = { title: "News & Announcements" };
export const dynamic = "force-dynamic";

export default async function NewsPage() {
  const [posts, announcements] = await Promise.all([
    prisma.newsPost.findMany({ where: { published: true }, orderBy: { createdAt: "desc" } }),
    prisma.announcement.findMany({ orderBy: [{ pinned: "desc" }, { createdAt: "desc" }] })
  ]);

  return (
    <>
      <Section title="Announcements">
        {announcements.length === 0 ? (
          <p className="text-muted-foreground">No announcements yet.</p>
        ) : (
          <div className="space-y-3">
            {announcements.map((a) => (
              <Card key={a.id}>
                <CardContent className="flex items-start justify-between gap-4 p-4">
                  <div>
                    <h3 className="font-semibold">{a.title}</h3>
                    <p className="text-sm text-muted-foreground">{a.body}</p>
                  </div>
                  {a.pinned && <Badge variant="accent">Pinned</Badge>}
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </Section>
      <Section title="News">
        <div className="grid gap-6 md:grid-cols-3">
          {posts.map((p) => (
            <Card key={p.id}>
              <CardContent className="p-6">
                <Badge className="mb-2">{p.category}</Badge>
                <h3 className="mb-1 font-semibold">{p.title}</h3>
                <p className="text-sm text-muted-foreground">{p.excerpt}</p>
                <p className="mt-3 text-xs text-muted-foreground">{formatDate(p.createdAt)}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </Section>
    </>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'app/(public)/page.tsx' <<'ETHCRYPT_HEREDOC_EOF'
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
ETHCRYPT_HEREDOC_EOF

write 'app/(public)/sponsors/page.tsx' <<'ETHCRYPT_HEREDOC_EOF'
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
ETHCRYPT_HEREDOC_EOF

write 'app/api/auth/[...nextauth]/route.ts' <<'ETHCRYPT_HEREDOC_EOF'
import NextAuth from "next-auth";
import { authOptions } from "@/lib/auth";

const handler = NextAuth(authOptions);
export { handler as GET, handler as POST };
ETHCRYPT_HEREDOC_EOF

write 'app/api/contact/route.ts' <<'ETHCRYPT_HEREDOC_EOF'
import { prisma } from "@/lib/prisma";
import { contactSchema } from "@/lib/validators";
import { ok, fail, handleZod } from "@/lib/api";
import { rateLimit, clientKey } from "@/lib/rate-limit";
import { sendMail } from "@/lib/mail";

export async function POST(req: Request) {
  const limit = rateLimit(clientKey(req, "contact"), 5, 60_000);
  if (!limit.ok) return fail("Too many messages. Try again shortly.", 429);

  try {
    const body = contactSchema.parse(await req.json());
    const message = await prisma.contactMessage.create({ data: body });

    const admin = process.env.ADMIN_EMAIL;
    if (admin) {
      await sendMail({
        to: admin,
        subject: `Contact: ${body.subject}`,
        html: `<p>From ${body.name} (${body.email}):</p><p>${body.message}</p>`
      }).catch(() => undefined);
    }

    return ok({ id: message.id }, 201);
  } catch (err) {
    return handleZod(err);
  }
}
ETHCRYPT_HEREDOC_EOF

write 'app/api/health/route.ts' <<'ETHCRYPT_HEREDOC_EOF'
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return NextResponse.json({ status: "ok", db: "up", time: new Date().toISOString() });
  } catch {
    return NextResponse.json({ status: "degraded", db: "down" }, { status: 503 });
  }
}
ETHCRYPT_HEREDOC_EOF

write 'app/api/leaderboard/route.ts' <<'ETHCRYPT_HEREDOC_EOF'
import { computeLeaderboard } from "@/lib/scoring";
import { ok } from "@/lib/api";

export const dynamic = "force-dynamic";

export async function GET() {
  const rows = await computeLeaderboard();
  return ok({ leaderboard: rows });
}
ETHCRYPT_HEREDOC_EOF

write 'app/api/register/route.ts' <<'ETHCRYPT_HEREDOC_EOF'
import bcrypt from "bcryptjs";
import { prisma } from "@/lib/prisma";
import { registerSchema } from "@/lib/validators";
import { ok, fail, handleZod } from "@/lib/api";
import { rateLimit, clientKey } from "@/lib/rate-limit";
import { sendMail } from "@/lib/mail";

export async function POST(req: Request) {
  const limit = rateLimit(clientKey(req, "register"), 5, 60_000);
  if (!limit.ok) return fail("Too many attempts. Try again shortly.", 429);

  try {
    const body = registerSchema.parse(await req.json());
    const existing = await prisma.user.findUnique({ where: { email: body.email } });
    if (existing) return fail("An account with that email already exists.", 409);

    const user = await prisma.user.create({
      data: {
        name: body.name,
        email: body.email,
        institution: body.institution,
        passwordHash: await bcrypt.hash(body.password, 10)
      },
      select: { id: true, email: true, name: true }
    });

    await sendMail({
      to: user.email,
      subject: "Welcome to EthCrypt",
      html: `<p>Hi ${user.name}, your EthCrypt account is ready. Log in to form a team and start solving.</p>`
    }).catch(() => undefined);

    return ok({ user }, 201);
  } catch (err) {
    return handleZod(err);
  }
}
ETHCRYPT_HEREDOC_EOF

write 'app/api/submissions/route.ts' <<'ETHCRYPT_HEREDOC_EOF'
import { prisma } from "@/lib/prisma";
import { getCurrentUser } from "@/lib/session";
import { flagSubmissionSchema } from "@/lib/validators";
import { verifyFlag } from "@/lib/utils";
import { ok, fail, handleZod } from "@/lib/api";
import { rateLimit } from "@/lib/rate-limit";

export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user) return fail("You must be logged in.", 401);
  if (user.role === "GUEST") return fail("Guests cannot submit flags.", 403);

  const limit = rateLimit(`submit:${user.id}`, 20, 60_000);
  if (!limit.ok) return fail("Slow down — too many submissions.", 429);

  try {
    const { challengeId, flag } = flagSubmissionSchema.parse(await req.json());

    const dbUser = await prisma.user.findUnique({
      where: { id: user.id },
      select: { teamId: true, disqualified: true }
    });
    if (dbUser?.disqualified) return fail("Your account is disqualified.", 403);
    if (!dbUser?.teamId) return fail("Join a team before submitting flags.", 400);

    const challenge = await prisma.challenge.findUnique({ where: { id: challengeId } });
    if (!challenge || !challenge.published) return fail("Challenge not found.", 404);

    const correct = verifyFlag(flag, challenge.flagHash);

    await prisma.submission.create({
      data: { challengeId, userId: user.id, teamId: dbUser.teamId, submitted: flag, correct }
    });

    if (!correct) return ok({ correct: false });

    // First correct solve for this team on this challenge wins the points.
    const existing = await prisma.solve.findUnique({
      where: { challengeId_teamId: { challengeId, teamId: dbUser.teamId } }
    });
    if (!existing) {
      await prisma.solve.create({
        data: { challengeId, userId: user.id, teamId: dbUser.teamId, points: challenge.points }
      });
    }

    return ok({ correct: true, points: challenge.points });
  } catch (err) {
    return handleZod(err);
  }
}
ETHCRYPT_HEREDOC_EOF

write 'app/api/teams/create/route.ts' <<'ETHCRYPT_HEREDOC_EOF'
import { prisma } from "@/lib/prisma";
import { getCurrentUser } from "@/lib/session";
import { teamCreateSchema } from "@/lib/validators";
import { inviteCode } from "@/lib/utils";
import { ok, fail, handleZod } from "@/lib/api";

export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user) return fail("You must be logged in.", 401);

  try {
    const body = teamCreateSchema.parse(await req.json());

    const me = await prisma.user.findUnique({ where: { id: user.id }, select: { teamId: true } });
    if (me?.teamId) return fail("You are already in a team.", 400);

    const exists = await prisma.team.findUnique({ where: { name: body.name } });
    if (exists) return fail("That team name is taken.", 409);

    const event = await prisma.event.findFirst({ where: { isCurrent: true } });

    const team = await prisma.team.create({
      data: {
        name: body.name,
        institution: body.institution,
        inviteCode: inviteCode(),
        approved: true,
        eventId: event?.id,
        captainId: user.id,
        members: { connect: { id: user.id } }
      }
    });

    await prisma.auditLog.create({
      data: { actorId: user.id, action: "team.create", target: team.id }
    });

    return ok({ team: { id: team.id, name: team.name, inviteCode: team.inviteCode } }, 201);
  } catch (err) {
    return handleZod(err);
  }
}
ETHCRYPT_HEREDOC_EOF

write 'app/api/teams/join/route.ts' <<'ETHCRYPT_HEREDOC_EOF'
import { prisma } from "@/lib/prisma";
import { getCurrentUser } from "@/lib/session";
import { teamJoinSchema } from "@/lib/validators";
import { ok, fail, handleZod } from "@/lib/api";

const MAX_TEAM_SIZE = 5;

export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user) return fail("You must be logged in.", 401);

  try {
    const { inviteCode } = teamJoinSchema.parse(await req.json());

    const me = await prisma.user.findUnique({ where: { id: user.id }, select: { teamId: true } });
    if (me?.teamId) return fail("You are already in a team.", 400);

    const team = await prisma.team.findUnique({
      where: { inviteCode: inviteCode.toUpperCase() },
      include: { _count: { select: { members: true } } }
    });
    if (!team) return fail("Invalid invite code.", 404);
    if (team._count.members >= MAX_TEAM_SIZE) return fail("That team is full.", 400);

    await prisma.user.update({ where: { id: user.id }, data: { teamId: team.id } });
    await prisma.auditLog.create({
      data: { actorId: user.id, action: "team.join", target: team.id }
    });

    return ok({ team: { id: team.id, name: team.name } });
  } catch (err) {
    return handleZod(err);
  }
}
ETHCRYPT_HEREDOC_EOF

write 'app/globals.css' <<'ETHCRYPT_HEREDOC_EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --radius: 0.5rem;
  --background: 210 40% 98%;
  --foreground: 222 47% 11%;
  --card: 0 0% 100%;
  --card-foreground: 222 47% 11%;
  --primary: 217 71% 14%;          /* deep navy */
  --primary-foreground: 210 40% 98%;
  --secondary: 210 40% 94%;
  --secondary-foreground: 222 47% 11%;
  --muted: 210 40% 94%;
  --muted-foreground: 215 16% 40%;
  --accent: 142 77% 30%;           /* Ethiopian green */
  --accent-foreground: 0 0% 100%;
  --destructive: 0 84% 46%;        /* Ethiopian red */
  --destructive-foreground: 0 0% 100%;
  --border: 214 32% 86%;
  --input: 214 32% 86%;
  --ring: 142 77% 30%;
}

.dark {
  --background: 222 47% 7%;
  --foreground: 210 40% 96%;
  --card: 222 45% 10%;
  --card-foreground: 210 40% 96%;
  --primary: 210 40% 96%;
  --primary-foreground: 222 47% 11%;
  --secondary: 217 33% 17%;
  --secondary-foreground: 210 40% 96%;
  --muted: 217 33% 17%;
  --muted-foreground: 215 20% 65%;
  --accent: 142 64% 42%;
  --accent-foreground: 222 47% 7%;
  --destructive: 0 72% 51%;
  --destructive-foreground: 0 0% 100%;
  --border: 217 33% 20%;
  --input: 217 33% 22%;
  --ring: 142 64% 42%;
}

* {
  border-color: hsl(var(--border));
}

body {
  background-color: hsl(var(--background));
  color: hsl(var(--foreground));
  font-feature-settings: "rlig" 1, "calt" 1;
}

.eth-stripe {
  background: linear-gradient(90deg, #118A3D 0 33%, #F5C518 33% 66%, #DA1212 66% 100%);
}
ETHCRYPT_HEREDOC_EOF

write 'app/layout.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import type { Metadata } from "next";
import { Inter, Sora } from "next/font/google";
import "./globals.css";
import { Providers } from "@/components/providers";

const inter = Inter({ subsets: ["latin"], variable: "--font-sans", display: "swap" });
const sora = Sora({ subsets: ["latin"], variable: "--font-display", display: "swap" });

const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";

export const metadata: Metadata = {
  metadataBase: new URL(appUrl),
  title: {
    default: "EthCrypt — Ethiopian Cyber Security Challenge",
    template: "%s · EthCrypt"
  },
  description:
    "The annual Ethiopian Cyber Security Challenge and symposium, hosted by Dire Dawa University. Register, compete in CTF challenges, and climb the leaderboard.",
  keywords: ["CTF", "cybersecurity", "Ethiopia", "Dire Dawa University", "EthCrypt"],
  openGraph: {
    title: "EthCrypt — Ethiopian Cyber Security Challenge",
    description: "Register, compete, and climb the leaderboard.",
    url: appUrl,
    siteName: "EthCrypt",
    type: "website"
  },
  robots: { index: true, follow: true }
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${inter.variable} ${sora.variable} font-sans antialiased`}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'app/not-found.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 text-center">
      <h1 className="font-display text-6xl font-bold text-accent">404</h1>
      <p className="text-muted-foreground">This page could not be found.</p>
      <Link href="/"><Button variant="accent">Back to home</Button></Link>
    </div>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'app/robots.ts' <<'ETHCRYPT_HEREDOC_EOF'
import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  const base = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";
  return {
    rules: { userAgent: "*", allow: "/", disallow: ["/admin", "/dashboard", "/api"] },
    sitemap: `${base}/sitemap.xml`
  };
}
ETHCRYPT_HEREDOC_EOF

write 'app/sitemap.ts' <<'ETHCRYPT_HEREDOC_EOF'
import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const base = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";
  const routes = ["", "/about", "/events", "/challenges", "/leaderboard", "/news", "/sponsors", "/contact", "/faq"];
  return routes.map((r) => ({ url: `${base}${r}`, lastModified: new Date() }));
}
ETHCRYPT_HEREDOC_EOF

write 'components/features/countdown.tsx' <<'ETHCRYPT_HEREDOC_EOF'
"use client";

import { useEffect, useState } from "react";

function diff(target: number) {
  const total = Math.max(0, target - Date.now());
  return {
    days: Math.floor(total / 864e5),
    hours: Math.floor((total / 36e5) % 24),
    minutes: Math.floor((total / 6e4) % 60),
    seconds: Math.floor((total / 1e3) % 60)
  };
}

export function Countdown({ target }: { target: string }) {
  const t = new Date(target).getTime();
  const [time, setTime] = useState(() => diff(t));

  useEffect(() => {
    const id = setInterval(() => setTime(diff(t)), 1000);
    return () => clearInterval(id);
  }, [t]);

  const units: [string, number][] = [
    ["Days", time.days],
    ["Hours", time.hours],
    ["Minutes", time.minutes],
    ["Seconds", time.seconds]
  ];

  return (
    <div className="grid grid-cols-4 gap-3">
      {units.map(([label, value]) => (
        <div key={label} className="rounded-lg border bg-card/60 p-4 text-center backdrop-blur">
          <div className="font-display text-3xl font-bold tabular-nums text-accent md:text-4xl">
            {String(value).padStart(2, "0")}
          </div>
          <div className="mt-1 text-xs uppercase tracking-wide text-muted-foreground">{label}</div>
        </div>
      ))}
    </div>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'components/features/flag-form.tsx' <<'ETHCRYPT_HEREDOC_EOF'
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export function FlagForm({ challengeId, solved }: { challengeId: string; solved: boolean }) {
  const router = useRouter();
  const [flag, setFlag] = useState("");
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [loading, setLoading] = useState(false);

  if (solved) return <p className="text-sm font-medium text-accent">Solved ✓</p>;

  async function submit() {
    setLoading(true);
    setMsg(null);
    const res = await fetch("/api/submissions", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ challengeId, flag })
    });
    const data = await res.json().catch(() => ({}));
    setLoading(false);

    if (res.ok && data.correct) {
      setMsg({ ok: true, text: "Correct flag — points awarded." });
      setFlag("");
      router.refresh();
    } else if (res.ok) {
      setMsg({ ok: false, text: "Incorrect flag. Try again." });
    } else {
      setMsg({ ok: false, text: data.error ?? "Submission failed." });
    }
  }

  return (
    <div className="space-y-2">
      <div className="flex gap-2">
        <Input
          value={flag}
          onChange={(e) => setFlag(e.target.value)}
          placeholder="ETHC{...}"
          className="font-mono"
        />
        <Button variant="accent" onClick={submit} disabled={loading || flag.length === 0}>
          {loading ? "…" : "Submit"}
        </Button>
      </div>
      {msg && <p className={msg.ok ? "text-sm text-accent" : "text-sm text-destructive"}>{msg.text}</p>}
    </div>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'components/features/leaderboard-table.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import type { LeaderboardRow } from "@/types";
import { Badge } from "@/components/ui/badge";

export function LeaderboardTable({ rows }: { rows: LeaderboardRow[] }) {
  if (rows.length === 0) {
    return (
      <div className="rounded-lg border border-dashed p-12 text-center text-muted-foreground">
        No scores yet. The board updates as teams solve challenges.
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-lg border">
      <table className="w-full text-sm">
        <thead className="bg-secondary text-left">
          <tr>
            <th className="px-4 py-3 font-medium">Rank</th>
            <th className="px-4 py-3 font-medium">Team</th>
            <th className="px-4 py-3 text-right font-medium">Solves</th>
            <th className="px-4 py-3 text-right font-medium">Score</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.teamId} className="border-t hover:bg-secondary/50">
              <td className="px-4 py-3">
                {row.rank <= 3 ? (
                  <Badge variant="accent">#{row.rank}</Badge>
                ) : (
                  <span className="text-muted-foreground">#{row.rank}</span>
                )}
              </td>
              <td className="px-4 py-3 font-medium">{row.teamName}</td>
              <td className="px-4 py-3 text-right tabular-nums">{row.solves}</td>
              <td className="px-4 py-3 text-right font-semibold tabular-nums text-accent">{row.score}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'components/features/section.tsx' <<'ETHCRYPT_HEREDOC_EOF'
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
ETHCRYPT_HEREDOC_EOF

write 'components/features/team-panel.tsx' <<'ETHCRYPT_HEREDOC_EOF'
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Copy, Users } from "lucide-react";

type Team = { id: string; name: string; inviteCode: string; approved: boolean } | null;

export function TeamPanel({ team }: { team: Team }) {
  const router = useRouter();
  const [name, setName] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function call(path: string, body: object) {
    setLoading(true);
    setError(null);
    const res = await fetch(path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });
    setLoading(false);
    if (res.ok) router.refresh();
    else {
      const data = await res.json().catch(() => ({}));
      setError(data.error ?? "Request failed.");
    }
  }

  if (team) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Users className="h-5 w-5 text-accent" /> {team.name}
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            Invite teammates with this code:
          </p>
          <div className="mt-2 flex items-center gap-2">
            <code className="rounded bg-secondary px-3 py-1 font-mono text-sm">{team.inviteCode}</code>
            <Button
              size="sm"
              variant="ghost"
              onClick={() => navigator.clipboard.writeText(team.inviteCode)}
              aria-label="Copy invite code"
            >
              <Copy className="h-4 w-4" />
            </Button>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader><CardTitle>Your team</CardTitle></CardHeader>
      <CardContent className="grid gap-6 md:grid-cols-2">
        <div className="space-y-2">
          <p className="text-sm font-medium">Create a team</p>
          <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Team name" />
          <Button variant="accent" disabled={loading || name.length < 2} onClick={() => call("/api/teams/create", { name })}>
            Create
          </Button>
        </div>
        <div className="space-y-2">
          <p className="text-sm font-medium">Join with a code</p>
          <Input value={code} onChange={(e) => setCode(e.target.value)} placeholder="Invite code" className="font-mono" />
          <Button variant="outline" disabled={loading || code.length < 4} onClick={() => call("/api/teams/join", { inviteCode: code })}>
            Join
          </Button>
        </div>
        {error && <p className="text-sm text-destructive md:col-span-2">{error}</p>}
      </CardContent>
    </Card>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'components/layout/footer.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import Link from "next/link";
import { Shield } from "lucide-react";

export function Footer() {
  return (
    <footer className="border-t bg-card">
      <div className="eth-stripe h-1 w-full" />
      <div className="container grid gap-8 py-12 md:grid-cols-4">
        <div className="space-y-2">
          <div className="flex items-center gap-2 font-display text-lg font-bold">
            <Shield className="h-5 w-5 text-accent" /> EthCrypt
          </div>
          <p className="text-sm text-muted-foreground">
            Ethiopian Cyber Security Challenge, hosted by Dire Dawa University.
          </p>
        </div>
        <div>
          <h4 className="mb-3 text-sm font-semibold">Platform</h4>
          <ul className="space-y-2 text-sm text-muted-foreground">
            <li><Link href="/challenges" className="hover:text-foreground">Challenges</Link></li>
            <li><Link href="/leaderboard" className="hover:text-foreground">Leaderboard</Link></li>
            <li><Link href="/events" className="hover:text-foreground">Events</Link></li>
          </ul>
        </div>
        <div>
          <h4 className="mb-3 text-sm font-semibold">Organization</h4>
          <ul className="space-y-2 text-sm text-muted-foreground">
            <li><Link href="/about" className="hover:text-foreground">About</Link></li>
            <li><Link href="/sponsors" className="hover:text-foreground">Sponsors</Link></li>
            <li><Link href="/contact" className="hover:text-foreground">Contact</Link></li>
          </ul>
        </div>
        <div>
          <h4 className="mb-3 text-sm font-semibold">Legal</h4>
          <ul className="space-y-2 text-sm text-muted-foreground">
            <li><Link href="/faq" className="hover:text-foreground">FAQ</Link></li>
            <li><Link href="/faq#terms" className="hover:text-foreground">Terms</Link></li>
            <li><Link href="/faq#privacy" className="hover:text-foreground">Privacy</Link></li>
          </ul>
        </div>
      </div>
      <div className="border-t py-6 text-center text-sm text-muted-foreground">
        © {new Date().getFullYear()} EthCrypt — Dire Dawa University. All rights reserved.
      </div>
    </footer>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'components/layout/navbar.tsx' <<'ETHCRYPT_HEREDOC_EOF'
"use client";

import Link from "next/link";
import { useSession, signOut } from "next-auth/react";
import { Shield, Menu, X } from "lucide-react";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { ThemeToggle } from "@/components/layout/theme-toggle";

const links = [
  { href: "/about", label: "About" },
  { href: "/events", label: "Events" },
  { href: "/challenges", label: "Challenges" },
  { href: "/leaderboard", label: "Leaderboard" },
  { href: "/news", label: "News" },
  { href: "/sponsors", label: "Sponsors" },
  { href: "/contact", label: "Contact" }
];

export function Navbar() {
  const { data: session } = useSession();
  const [open, setOpen] = useState(false);

  return (
    <header className="sticky top-0 z-40 w-full border-b bg-background/80 backdrop-blur">
      <div className="eth-stripe h-1 w-full" />
      <div className="container flex h-16 items-center justify-between">
        <Link href="/" className="flex items-center gap-2 font-display text-lg font-bold">
          <Shield className="h-6 w-6 text-accent" />
          EthCrypt
        </Link>

        <nav className="hidden items-center gap-6 md:flex">
          {links.map((l) => (
            <Link key={l.href} href={l.href} className="text-sm text-muted-foreground hover:text-foreground">
              {l.label}
            </Link>
          ))}
        </nav>

        <div className="hidden items-center gap-2 md:flex">
          <ThemeToggle />
          {session ? (
            <>
              {(session.user.role === "ADMIN" || session.user.role === "JUDGE") && (
                <Link href="/admin"><Button variant="outline" size="sm">Admin</Button></Link>
              )}
              <Link href="/dashboard"><Button variant="outline" size="sm">Dashboard</Button></Link>
              <Button size="sm" onClick={() => signOut({ callbackUrl: "/" })}>Sign out</Button>
            </>
          ) : (
            <>
              <Link href="/login"><Button variant="outline" size="sm">Log in</Button></Link>
              <Link href="/register"><Button variant="accent" size="sm">Register</Button></Link>
            </>
          )}
        </div>

        <div className="flex items-center gap-1 md:hidden">
          <ThemeToggle />
          <Button variant="ghost" size="icon" aria-label="Menu" onClick={() => setOpen(!open)}>
            {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
          </Button>
        </div>
      </div>

      {open && (
        <div className="border-t px-6 py-4 md:hidden">
          <nav className="flex flex-col gap-3">
            {links.map((l) => (
              <Link key={l.href} href={l.href} onClick={() => setOpen(false)} className="text-sm text-muted-foreground hover:text-foreground">
                {l.label}
              </Link>
            ))}
            <div className="mt-2 flex gap-2">
              {session ? (
                <Button size="sm" onClick={() => signOut({ callbackUrl: "/" })}>Sign out</Button>
              ) : (
                <>
                  <Link href="/login" className="flex-1"><Button variant="outline" size="sm" className="w-full">Log in</Button></Link>
                  <Link href="/register" className="flex-1"><Button variant="accent" size="sm" className="w-full">Register</Button></Link>
                </>
              )}
            </div>
          </nav>
        </div>
      )}
    </header>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'components/layout/theme-toggle.tsx' <<'ETHCRYPT_HEREDOC_EOF'
"use client";

import { Moon, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  if (!mounted) return <Button variant="ghost" size="icon" aria-label="Toggle theme" />;

  return (
    <Button
      variant="ghost"
      size="icon"
      aria-label="Toggle theme"
      onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
    >
      {theme === "dark" ? <Sun className="h-5 w-5" /> : <Moon className="h-5 w-5" />}
    </Button>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'components/providers.tsx' <<'ETHCRYPT_HEREDOC_EOF'
"use client";

import { ThemeProvider } from "next-themes";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { SessionProvider } from "next-auth/react";
import { useState } from "react";

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());
  return (
    <SessionProvider>
      <QueryClientProvider client={queryClient}>
        <ThemeProvider attribute="class" defaultTheme="dark" enableSystem>
          {children}
        </ThemeProvider>
      </QueryClientProvider>
    </SessionProvider>
  );
}
ETHCRYPT_HEREDOC_EOF

write 'components/ui/badge.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import * as React from "react";
import { cn } from "@/lib/utils";

const styles: Record<string, string> = {
  default: "bg-secondary text-secondary-foreground",
  accent: "bg-accent text-accent-foreground",
  outline: "border border-input"
};

export function Badge({
  className,
  variant = "default",
  ...props
}: React.HTMLAttributes<HTMLSpanElement> & { variant?: keyof typeof styles }) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
        styles[variant],
        className
      )}
      {...props}
    />
  );
}
ETHCRYPT_HEREDOC_EOF

write 'components/ui/button.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:opacity-90",
        accent: "bg-accent text-accent-foreground hover:opacity-90",
        destructive: "bg-destructive text-destructive-foreground hover:opacity-90",
        outline: "border border-input bg-transparent hover:bg-secondary",
        ghost: "hover:bg-secondary",
        link: "text-accent underline-offset-4 hover:underline"
      },
      size: {
        default: "h-10 px-4 py-2",
        sm: "h-9 px-3",
        lg: "h-11 px-8",
        icon: "h-10 w-10"
      }
    },
    defaultVariants: { variant: "default", size: "default" }
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, ...props }, ref) => (
    <button ref={ref} className={cn(buttonVariants({ variant, size, className }))} {...props} />
  )
);
Button.displayName = "Button";
export { buttonVariants };
ETHCRYPT_HEREDOC_EOF

write 'components/ui/card.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import * as React from "react";
import { cn } from "@/lib/utils";

export const Card = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn("rounded-lg border bg-card text-card-foreground shadow-sm", className)} {...props} />
  )
);
Card.displayName = "Card";

export function CardHeader({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("flex flex-col space-y-1.5 p-6", className)} {...props} />;
}
export function CardTitle({ className, ...props }: React.HTMLAttributes<HTMLHeadingElement>) {
  return <h3 className={cn("text-lg font-semibold leading-none tracking-tight", className)} {...props} />;
}
export function CardDescription({ className, ...props }: React.HTMLAttributes<HTMLParagraphElement>) {
  return <p className={cn("text-sm text-muted-foreground", className)} {...props} />;
}
export function CardContent({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("p-6 pt-0", className)} {...props} />;
}
export function CardFooter({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("flex items-center p-6 pt-0", className)} {...props} />;
}
ETHCRYPT_HEREDOC_EOF

write 'components/ui/input.tsx' <<'ETHCRYPT_HEREDOC_EOF'
import * as React from "react";
import { cn } from "@/lib/utils";

export const Input = React.forwardRef<HTMLInputElement, React.InputHTMLAttributes<HTMLInputElement>>(
  ({ className, type, ...props }, ref) => (
    <input
      type={type}
      ref={ref}
      className={cn(
        "flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
        className
      )}
      {...props}
    />
  )
);
Input.displayName = "Input";
ETHCRYPT_HEREDOC_EOF

write 'lib/api.ts' <<'ETHCRYPT_HEREDOC_EOF'
import { NextResponse } from "next/server";
import { ZodError } from "zod";

export type ApiError = { error: string; details?: unknown };

export function ok<T>(data: T, status = 200) {
  return NextResponse.json(data, { status });
}

export function fail(message: string, status = 400, details?: unknown) {
  return NextResponse.json<ApiError>({ error: message, details }, { status });
}

export function handleZod(err: unknown) {
  if (err instanceof ZodError) {
    return fail("Validation failed", 422, err.flatten().fieldErrors);
  }
  console.error(err);
  return fail("Something went wrong", 500);
}
ETHCRYPT_HEREDOC_EOF

write 'lib/auth.ts' <<'ETHCRYPT_HEREDOC_EOF'
import type { NextAuthOptions } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";
import GoogleProvider from "next-auth/providers/google";
import bcrypt from "bcryptjs";
import { prisma } from "@/lib/prisma";
import { loginSchema } from "@/lib/validators";
import type { Role } from "@prisma/client";

const providers: NextAuthOptions["providers"] = [
  CredentialsProvider({
    name: "Credentials",
    credentials: {
      email: { label: "Email", type: "email" },
      password: { label: "Password", type: "password" }
    },
    async authorize(credentials) {
      const parsed = loginSchema.safeParse(credentials);
      if (!parsed.success) return null;

      const user = await prisma.user.findUnique({
        where: { email: parsed.data.email }
      });
      if (!user?.passwordHash) return null;

      const valid = await bcrypt.compare(parsed.data.password, user.passwordHash);
      if (!valid) return null;

      return {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role
      };
    }
  })
];

if (process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET) {
  providers.push(
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET
    })
  );
}

export const authOptions: NextAuthOptions = {
  session: { strategy: "jwt" },
  pages: { signIn: "/login" },
  providers,
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.role = (user as { role: Role }).role;
        token.id = user.id;
      } else if (token.email) {
        const db = await prisma.user.findUnique({ where: { email: token.email } });
        if (db) {
          token.role = db.role;
          token.id = db.id;
        }
      }
      return token;
    },
    async session({ session, token }) {
      if (session.user) {
        session.user.id = token.id as string;
        session.user.role = token.role as Role;
      }
      return session;
    }
  }
};
ETHCRYPT_HEREDOC_EOF

write 'lib/mail.ts' <<'ETHCRYPT_HEREDOC_EOF'
// Email sender. Uses Resend when RESEND_API_KEY is set; otherwise logs to console.
// This keeps local dev and CI dependency-free while remaining production-ready.

type MailInput = { to: string; subject: string; html: string };

export async function sendMail({ to, subject, html }: MailInput): Promise<void> {
  const key = process.env.RESEND_API_KEY;
  const from = process.env.EMAIL_FROM ?? "EthCrypt <no-reply@ethcrypt.ddu.edu.et>";

  if (!key) {
    console.info(`[mail:dev] to=${to} subject="${subject}"`);
    return;
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ from, to, subject, html })
  });

  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`Resend failed (${res.status}): ${detail}`);
  }
}
ETHCRYPT_HEREDOC_EOF

write 'lib/prisma.ts' <<'ETHCRYPT_HEREDOC_EOF'
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === "development" ? ["error", "warn"] : ["error"]
  });

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;
ETHCRYPT_HEREDOC_EOF

write 'lib/rate-limit.ts' <<'ETHCRYPT_HEREDOC_EOF'
// Lightweight in-memory rate limiter (per-process). Suitable for a single
// Render web instance. Swap for Upstash/Redis when scaling horizontally.

type Bucket = { count: number; resetAt: number };
const buckets = new Map<string, Bucket>();

export function rateLimit(key: string, limit = 10, windowMs = 60_000) {
  const now = Date.now();
  const bucket = buckets.get(key);

  if (!bucket || bucket.resetAt < now) {
    buckets.set(key, { count: 1, resetAt: now + windowMs });
    return { ok: true, remaining: limit - 1 };
  }

  if (bucket.count >= limit) {
    return { ok: false, remaining: 0, retryAfter: bucket.resetAt - now };
  }

  bucket.count += 1;
  return { ok: true, remaining: limit - bucket.count };
}

export function clientKey(req: Request, scope: string): string {
  const fwd = req.headers.get("x-forwarded-for") ?? "local";
  return `${scope}:${fwd.split(",")[0].trim()}`;
}
ETHCRYPT_HEREDOC_EOF

write 'lib/scoring.ts' <<'ETHCRYPT_HEREDOC_EOF'
import { prisma } from "@/lib/prisma";
import type { LeaderboardRow } from "@/types";

// Aggregate team scores from solves + manual adjustments into a ranked board.
export async function computeLeaderboard(): Promise<LeaderboardRow[]> {
  const [teams, solves, adjustments] = await Promise.all([
    prisma.team.findMany({ where: { approved: true }, select: { id: true, name: true, frozen: true } }),
    prisma.solve.groupBy({
      by: ["teamId"],
      _sum: { points: true },
      _count: { _all: true }
    }),
    prisma.scoreAdjustment.groupBy({ by: ["teamId"], _sum: { delta: true } })
  ]);

  const solveMap = new Map(solves.map((s) => [s.teamId, s]));
  const adjMap = new Map(adjustments.map((a) => [a.teamId, a._sum.delta ?? 0]));

  const rows = teams.map((team) => {
    const s = solveMap.get(team.id);
    const base = s?._sum.points ?? 0;
    const adj = adjMap.get(team.id) ?? 0;
    return {
      teamId: team.id,
      teamName: team.name,
      score: base + adj,
      solves: s?._count._all ?? 0,
      rank: 0
    };
  });

  rows.sort((a, b) => b.score - a.score || b.solves - a.solves);
  rows.forEach((r, i) => (r.rank = i + 1));
  return rows;
}
ETHCRYPT_HEREDOC_EOF

write 'lib/session.ts' <<'ETHCRYPT_HEREDOC_EOF'
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import type { Role } from "@prisma/client";

export async function getCurrentUser() {
  const session = await getServerSession(authOptions);
  return session?.user ?? null;
}

export async function requireRole(...roles: Role[]) {
  const user = await getCurrentUser();
  if (!user || !roles.includes(user.role)) return null;
  return user;
}
ETHCRYPT_HEREDOC_EOF

write 'lib/utils.ts' <<'ETHCRYPT_HEREDOC_EOF'
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";
import crypto from "crypto";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function hashFlag(flag: string): string {
  return crypto.createHash("sha256").update(flag.trim()).digest("hex");
}

export function verifyFlag(flag: string, hash: string): boolean {
  const candidate = hashFlag(flag);
  const a = Buffer.from(candidate);
  const b = Buffer.from(hash);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

export function inviteCode(): string {
  return crypto.randomBytes(4).toString("hex").toUpperCase();
}

export function certificateCode(): string {
  return "ETHC-" + crypto.randomBytes(5).toString("hex").toUpperCase();
}

export function formatDate(d: Date | string): string {
  return new Date(d).toLocaleDateString("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric"
  });
}
ETHCRYPT_HEREDOC_EOF

write 'lib/validators.ts' <<'ETHCRYPT_HEREDOC_EOF'
import { z } from "zod";

export const registerSchema = z.object({
  name: z.string().min(2, "Name is too short").max(80),
  email: z.string().email("Enter a valid email"),
  password: z.string().min(8, "Use at least 8 characters").max(100),
  institution: z.string().max(120).optional()
});
export type RegisterInput = z.infer<typeof registerSchema>;

export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1)
});

export const contactSchema = z.object({
  name: z.string().min(2).max(80),
  email: z.string().email(),
  subject: z.string().min(2).max(120),
  message: z.string().min(10).max(2000)
});
export type ContactInput = z.infer<typeof contactSchema>;

export const flagSubmissionSchema = z.object({
  challengeId: z.string().min(1),
  flag: z.string().min(1).max(200)
});

export const teamCreateSchema = z.object({
  name: z.string().min(2).max(60),
  institution: z.string().max(120).optional()
});

export const teamJoinSchema = z.object({
  inviteCode: z.string().min(4).max(16)
});

export const challengeSchema = z.object({
  eventId: z.string().min(1),
  title: z.string().min(2).max(120),
  category: z.enum([
    "WEB",
    "CRYPTO",
    "FORENSICS",
    "PWN",
    "REVERSING",
    "OSINT",
    "MISC"
  ]),
  description: z.string().min(10),
  points: z.number().int().min(1).max(1000),
  flag: z.string().min(1),
  published: z.boolean().optional()
});
ETHCRYPT_HEREDOC_EOF

write 'middleware.ts' <<'ETHCRYPT_HEREDOC_EOF'
import { withAuth } from "next-auth/middleware";
import { NextResponse } from "next/server";

export default withAuth(
  function middleware(req) {
    const { pathname } = req.nextUrl;
    const role = req.nextauth.token?.role;

    if (pathname.startsWith("/admin") && role !== "ADMIN" && role !== "JUDGE") {
      return NextResponse.redirect(new URL("/dashboard", req.url));
    }
    return NextResponse.next();
  },
  {
    callbacks: {
      authorized: ({ token }) => !!token
    },
    pages: { signIn: "/login" }
  }
);

export const config = {
  matcher: ["/dashboard/:path*", "/admin/:path*"]
};
ETHCRYPT_HEREDOC_EOF

write 'next-env.d.ts' <<'ETHCRYPT_HEREDOC_EOF'
/// <reference types="next" />
/// <reference types="next/image-types/global" />
ETHCRYPT_HEREDOC_EOF

write 'next.config.js' <<'ETHCRYPT_HEREDOC_EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "res.cloudinary.com" },
      { protocol: "https", hostname: "images.unsplash.com" }
    ]
  },
  eslint: { ignoreDuringBuilds: true },
  typescript: { ignoreBuildErrors: false }
};
module.exports = nextConfig;
ETHCRYPT_HEREDOC_EOF

write 'package.json' <<'ETHCRYPT_HEREDOC_EOF'
{
  "name": "ethcrypt",
  "version": "1.0.0",
  "private": true,
  "description": "EthCrypt — Ethiopian Cyber Security Challenge platform (Dire Dawa University)",
  "scripts": {
    "dev": "next dev",
    "build": "prisma generate && next build",
    "start": "next start",
    "lint": "next lint",
    "postinstall": "prisma generate",
    "db:migrate": "prisma migrate dev",
    "db:deploy": "prisma migrate deploy",
    "db:push": "prisma db push",
    "db:seed": "tsx prisma/seed.ts",
    "db:reset": "prisma migrate reset --force"
  },
  "prisma": {
    "seed": "tsx prisma/seed.ts"
  },
  "dependencies": {
    "@prisma/client": "^5.22.0",
    "@tanstack/react-query": "^5.59.0",
    "bcryptjs": "^2.4.3",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.1.1",
    "lucide-react": "^0.454.0",
    "next": "^14.2.15",
    "next-auth": "^4.24.10",
    "next-themes": "^0.3.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "tailwind-merge": "^2.5.4",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/bcryptjs": "^2.4.6",
    "@types/node": "^20.16.11",
    "@types/react": "^18.3.11",
    "@types/react-dom": "^18.3.0",
    "autoprefixer": "^10.4.20",
    "eslint": "^8.57.1",
    "eslint-config-next": "^14.2.15",
    "postcss": "^8.4.47",
    "prisma": "^5.22.0",
    "tailwindcss": "^3.4.14",
    "tsx": "^4.19.1",
    "typescript": "^5.6.3"
  },
  "engines": {
    "node": ">=18.18.0"
  }
}
ETHCRYPT_HEREDOC_EOF

write 'postcss.config.js' <<'ETHCRYPT_HEREDOC_EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {}
  }
};
ETHCRYPT_HEREDOC_EOF

write 'prisma/schema.prisma' <<'ETHCRYPT_HEREDOC_EOF'
// EthCrypt — Ethiopian Cyber Security Challenge
// Prisma schema. Data model covers the full platform even where UI is not yet built.

generator client {
  provider      = "prisma-client-js"
  // Render runs Debian OpenSSL 3.x; local dev is often the same. Cover both.
  binaryTargets = ["native", "debian-openssl-3.0.x", "debian-openssl-1.1.x"]
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

// ---------------------------------------------------------------------------
// Auth (NextAuth adapter compatible) + roles
// ---------------------------------------------------------------------------

enum Role {
  ADMIN
  JUDGE
  PARTICIPANT
  GUEST
}

model User {
  id            String    @id @default(cuid())
  name          String?
  email         String    @unique
  emailVerified DateTime?
  image         String?
  passwordHash  String?
  role          Role      @default(PARTICIPANT)
  institution   String?
  country       String?   @default("Ethiopia")
  bio           String?
  disqualified  Boolean   @default(false)

  accounts      Account[]
  sessions      Session[]

  teamId        String?
  team          Team?          @relation("TeamMembers", fields: [teamId], references: [id])
  captainOf     Team?          @relation("TeamCaptain")

  submissions   Submission[]
  solves        Solve[]
  auditLogs     AuditLog[]
  certificates  Certificate[]
  newsPosts     NewsPost[]

  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt

  @@index([role])
}

model Account {
  id                String  @id @default(cuid())
  userId            String
  type              String
  provider          String
  providerAccountId String
  refresh_token     String?
  access_token      String?
  expires_at        Int?
  token_type        String?
  scope             String?
  id_token          String?
  session_state     String?

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([provider, providerAccountId])
}

model Session {
  id           String   @id @default(cuid())
  sessionToken String   @unique
  userId       String
  expires      DateTime
  user         User     @relation(fields: [userId], references: [id], onDelete: Cascade)
}

model VerificationToken {
  identifier String
  token      String   @unique
  expires    DateTime

  @@unique([identifier, token])
}

// ---------------------------------------------------------------------------
// Teams
// ---------------------------------------------------------------------------

model Team {
  id          String   @id @default(cuid())
  name        String   @unique
  inviteCode  String   @unique
  approved    Boolean  @default(false)
  frozen      Boolean  @default(false)
  country     String?  @default("Ethiopia")
  institution String?

  captainId   String?  @unique
  captain     User?    @relation("TeamCaptain", fields: [captainId], references: [id])

  members     User[]       @relation("TeamMembers")
  submissions Submission[]
  solves      Solve[]

  eventId     String?
  event       Event?   @relation(fields: [eventId], references: [id])

  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  @@index([eventId])
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

model Event {
  id          String   @id @default(cuid())
  slug        String   @unique
  title       String
  year        Int
  description String
  location    String?
  startsAt    DateTime
  endsAt      DateTime
  isCurrent   Boolean  @default(false)
  frozen      Boolean  @default(false)

  challenges  Challenge[]
  teams       Team[]
  scheduleItems ScheduleItem[]

  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  @@index([year])
}

model ScheduleItem {
  id        String   @id @default(cuid())
  eventId   String
  event     Event    @relation(fields: [eventId], references: [id], onDelete: Cascade)
  title     String
  speaker   String?
  startsAt  DateTime
  endsAt    DateTime
  location  String?

  @@index([eventId])
}

// ---------------------------------------------------------------------------
// Challenges
// ---------------------------------------------------------------------------

enum ChallengeCategory {
  WEB
  CRYPTO
  FORENSICS
  PWN
  REVERSING
  OSINT
  MISC
}

model Challenge {
  id          String            @id @default(cuid())
  eventId     String
  event       Event             @relation(fields: [eventId], references: [id], onDelete: Cascade)
  title       String
  slug        String            @unique
  category    ChallengeCategory
  description String
  points      Int               @default(100)
  // Flag is stored hashed; never returned to clients.
  flagHash    String
  published   Boolean           @default(false)
  fileUrl     String?
  authorName  String?

  hints       Hint[]
  submissions Submission[]
  solves      Solve[]

  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  @@index([eventId, category])
}

model Hint {
  id          String    @id @default(cuid())
  challengeId String
  challenge   Challenge @relation(fields: [challengeId], references: [id], onDelete: Cascade)
  content     String
  cost        Int       @default(0)
  order       Int       @default(0)

  @@index([challengeId])
}

// ---------------------------------------------------------------------------
// Submissions, solves, scoring
// ---------------------------------------------------------------------------

model Submission {
  id          String    @id @default(cuid())
  challengeId String
  challenge   Challenge @relation(fields: [challengeId], references: [id], onDelete: Cascade)
  userId      String
  user        User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  teamId      String?
  team        Team?     @relation(fields: [teamId], references: [id])
  submitted   String
  correct     Boolean   @default(false)
  writeupUrl  String?
  createdAt   DateTime  @default(now())

  @@index([challengeId])
  @@index([userId])
  @@index([teamId])
}

// A Solve is the first correct submission for a (team, challenge) pair.
model Solve {
  id          String    @id @default(cuid())
  challengeId String
  challenge   Challenge @relation(fields: [challengeId], references: [id], onDelete: Cascade)
  userId      String
  user        User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  teamId      String?
  team        Team?     @relation(fields: [teamId], references: [id])
  points      Int
  createdAt   DateTime  @default(now())

  @@unique([challengeId, teamId])
  @@index([teamId])
}

// Manual point adjustments by judges/admins (bonus or penalty).
model ScoreAdjustment {
  id        String   @id @default(cuid())
  teamId    String
  delta     Int
  reason    String
  createdAt DateTime @default(now())

  @@index([teamId])
}

// ---------------------------------------------------------------------------
// Content: announcements, news, sponsors, contact, gallery
// ---------------------------------------------------------------------------

model Announcement {
  id        String   @id @default(cuid())
  title     String
  body      String
  pinned    Boolean  @default(false)
  createdAt DateTime @default(now())
}

model NewsPost {
  id        String   @id @default(cuid())
  slug      String   @unique
  title     String
  excerpt   String
  body      String
  category  String   @default("General")
  coverUrl  String?
  published Boolean  @default(true)
  authorId  String?
  author    User?    @relation(fields: [authorId], references: [id])
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([category])
}

enum SponsorTier {
  PLATINUM
  GOLD
  SILVER
  PARTNER
}

model Sponsor {
  id        String      @id @default(cuid())
  name      String
  tier      SponsorTier @default(PARTNER)
  logoUrl   String?
  website   String?
  createdAt DateTime    @default(now())
}

model GalleryItem {
  id        String   @id @default(cuid())
  eventYear Int?
  caption   String?
  mediaUrl  String
  type      String   @default("image") // image | video
  createdAt DateTime @default(now())
}

model ContactMessage {
  id        String   @id @default(cuid())
  name      String
  email     String
  subject   String
  message   String
  handled   Boolean  @default(false)
  createdAt DateTime @default(now())
}

// ---------------------------------------------------------------------------
// Certificates + audit log
// ---------------------------------------------------------------------------

model Certificate {
  id        String   @id @default(cuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  eventYear Int
  code      String   @unique
  createdAt DateTime @default(now())

  @@index([userId])
}

model AuditLog {
  id        String   @id @default(cuid())
  actorId   String?
  actor     User?    @relation(fields: [actorId], references: [id])
  action    String
  target    String?
  meta      String?
  createdAt DateTime @default(now())

  @@index([actorId])
}
ETHCRYPT_HEREDOC_EOF

write 'prisma/seed.ts' <<'ETHCRYPT_HEREDOC_EOF'
import { PrismaClient, ChallengeCategory, Role, SponsorTier } from "@prisma/client";
import bcrypt from "bcryptjs";
import crypto from "crypto";

const prisma = new PrismaClient();

const hashFlag = (f: string) =>
  crypto.createHash("sha256").update(f.trim()).digest("hex");
const invite = () => crypto.randomBytes(4).toString("hex").toUpperCase();
const slugify = (s: string) =>
  s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");

async function main() {
  console.log("Seeding EthCrypt…");

  // --- wipe (dev/demo only) ---
  await prisma.$transaction([
    prisma.solve.deleteMany(),
    prisma.submission.deleteMany(),
    prisma.hint.deleteMany(),
    prisma.challenge.deleteMany(),
    prisma.scheduleItem.deleteMany(),
    prisma.certificate.deleteMany(),
    prisma.auditLog.deleteMany(),
    prisma.newsPost.deleteMany(),
    prisma.announcement.deleteMany(),
    prisma.sponsor.deleteMany(),
    prisma.contactMessage.deleteMany(),
    prisma.galleryItem.deleteMany(),
    prisma.scoreAdjustment.deleteMany()
  ]);
  // Detach members before deleting teams/users
  await prisma.user.updateMany({ data: { teamId: null } });
  await prisma.team.deleteMany();
  await prisma.user.deleteMany();

  const adminEmail = process.env.ADMIN_EMAIL ?? "admin@ethcrypt.ddu.edu.et";
  const adminPassword = process.env.ADMIN_PASSWORD ?? "ChangeMe123!";

  // --- Users ---
  const admin = await prisma.user.create({
    data: {
      name: "EthCrypt Admin",
      email: adminEmail,
      role: Role.ADMIN,
      institution: "Dire Dawa University",
      passwordHash: await bcrypt.hash(adminPassword, 10)
    }
  });

  const commonHash = await bcrypt.hash("Password123!", 10);

  const judges = await Promise.all(
    ["Selam Abebe", "Yohannes Tesfaye"].map((name, i) =>
      prisma.user.create({
        data: {
          name,
          email: `judge${i + 1}@ethcrypt.ddu.edu.et`,
          role: Role.JUDGE,
          institution: "Dire Dawa University",
          passwordHash: commonHash
        }
      })
    )
  );

  const firstNames = [
    "Abel", "Bethlehem", "Dawit", "Eden", "Feven", "Girma", "Hana", "Ibrahim",
    "Kalkidan", "Liya", "Mekdes", "Nahom", "Robel", "Saba", "Tewodros",
    "Winta", "Yared", "Zufan", "Amanuel", "Bezawit"
  ];
  const participants = await Promise.all(
    firstNames.map((name, i) =>
      prisma.user.create({
        data: {
          name,
          email: `user${i + 1}@student.ddu.edu.et`,
          role: Role.PARTICIPANT,
          institution: "Dire Dawa University",
          passwordHash: commonHash
        }
      })
    )
  );

  // --- Events ---
  const now = new Date();
  const currentEvent = await prisma.event.create({
    data: {
      slug: "ethcrypt-2026",
      title: "EthCrypt Symposium 2026",
      year: 2026,
      description:
        "The annual Ethiopian Cyber Security Challenge hosted by Dire Dawa University — a two-day symposium and CTF bringing together students, researchers and industry.",
      location: "Dire Dawa University, Main Campus",
      startsAt: new Date(now.getTime() + 30 * 864e5),
      endsAt: new Date(now.getTime() + 32 * 864e5),
      isCurrent: true
    }
  });

  await prisma.event.createMany({
    data: [
      {
        slug: "ethcrypt-2025",
        title: "EthCrypt Symposium 2025",
        year: 2025,
        description: "The inaugural national cybersecurity challenge and symposium.",
        location: "Dire Dawa University",
        startsAt: new Date("2025-05-10"),
        endsAt: new Date("2025-05-11")
      },
      {
        slug: "ethcrypt-2024",
        title: "EthCrypt Pilot 2024",
        year: 2024,
        description: "A regional pilot event that seeded the national challenge.",
        location: "Dire Dawa",
        startsAt: new Date("2024-06-01"),
        endsAt: new Date("2024-06-01")
      }
    ]
  });

  await prisma.scheduleItem.createMany({
    data: [
      {
        eventId: currentEvent.id,
        title: "Opening keynote: The state of cyber in the Horn of Africa",
        speaker: "Dr. Selam Abebe",
        startsAt: new Date(now.getTime() + 30 * 864e5 + 9 * 36e5),
        endsAt: new Date(now.getTime() + 30 * 864e5 + 10 * 36e5),
        location: "Main Auditorium"
      },
      {
        eventId: currentEvent.id,
        title: "CTF competition begins",
        speaker: null,
        startsAt: new Date(now.getTime() + 30 * 864e5 + 11 * 36e5),
        endsAt: new Date(now.getTime() + 31 * 864e5 + 11 * 36e5),
        location: "Computing Labs"
      }
    ]
  });

  // --- Teams (6), assign participants, first member is captain ---
  const teamNames = [
    "Nyala Defenders",
    "Addis Overflow",
    "Rift Valley Root",
    "Sheba Shellcode",
    "Blue Nile Bytes",
    "Harar Hashcats"
  ];
  const teams = [];
  for (let t = 0; t < teamNames.length; t++) {
    const members = participants.slice(t * 3, t * 3 + 3);
    const team = await prisma.team.create({
      data: {
        name: teamNames[t],
        inviteCode: invite(),
        approved: true,
        institution: "Dire Dawa University",
        eventId: currentEvent.id,
        captainId: members[0]?.id,
        members: { connect: members.map((m) => ({ id: m.id })) }
      }
    });
    teams.push({ team, members });
  }

  // --- Challenges (15) ---
  const challengeDefs: {
    title: string;
    category: ChallengeCategory;
    points: number;
    flag: string;
    description: string;
  }[] = [
    { title: "Cookie Monster", category: ChallengeCategory.WEB, points: 100, flag: "ETHC{tamper_the_cookie}", description: "A login form trusts a client-side cookie a little too much." },
    { title: "SQL Safari", category: ChallengeCategory.WEB, points: 200, flag: "ETHC{union_based_win}", description: "Find the flag hidden behind an injectable search box." },
    { title: "JWT None", category: ChallengeCategory.WEB, points: 250, flag: "ETHC{alg_none_bypass}", description: "The API validates tokens, but does it validate the algorithm?" },
    { title: "XOR Me Not", category: ChallengeCategory.CRYPTO, points: 150, flag: "ETHC{single_byte_xor}", description: "A message encrypted with a one-byte key. Recover it." },
    { title: "RSA Rookie", category: ChallengeCategory.CRYPTO, points: 200, flag: "ETHC{small_e_attack}", description: "Textbook RSA with a very small exponent." },
    { title: "Padding Party", category: ChallengeCategory.CRYPTO, points: 300, flag: "ETHC{padding_oracle}", description: "A padding oracle leaks one byte at a time." },
    { title: "Deleted But Not Gone", category: ChallengeCategory.FORENSICS, points: 150, flag: "ETHC{carve_the_jpeg}", description: "Recover a file that was deleted from this disk image." },
    { title: "Packet Whisperer", category: ChallengeCategory.FORENSICS, points: 200, flag: "ETHC{follow_the_stream}", description: "The flag was exfiltrated over the network. Find it in the pcap." },
    { title: "Stego Sunset", category: ChallengeCategory.FORENSICS, points: 250, flag: "ETHC{lsb_in_the_pixels}", description: "This sunset photo hides more than colors." },
    { title: "Baby Overflow", category: ChallengeCategory.PWN, points: 200, flag: "ETHC{smashed_the_stack}", description: "A classic stack buffer overflow to redirect execution." },
    { title: "Format Fun", category: ChallengeCategory.PWN, points: 300, flag: "ETHC{printf_leak}", description: "An uncontrolled format string leaks and writes memory." },
    { title: "Crackme Zero", category: ChallengeCategory.REVERSING, points: 150, flag: "ETHC{static_strings}", description: "Reverse a small binary to find the accepted password." },
    { title: "VM Riddle", category: ChallengeCategory.REVERSING, points: 350, flag: "ETHC{custom_bytecode}", description: "A tiny custom virtual machine guards the flag." },
    { title: "Find The Founder", category: ChallengeCategory.OSINT, points: 100, flag: "ETHC{open_source_intel}", description: "Use public sources to identify the account behind the leak." },
    { title: "Geoguess DDU", category: ChallengeCategory.OSINT, points: 150, flag: "ETHC{pin_the_campus}", description: "Locate exactly where on campus this photo was taken." }
  ];

  const challenges = [];
  for (const c of challengeDefs) {
    const created = await prisma.challenge.create({
      data: {
        eventId: currentEvent.id,
        title: c.title,
        slug: slugify(c.title),
        category: c.category,
        description: c.description,
        points: c.points,
        flagHash: hashFlag(c.flag),
        published: true,
        authorName: "EthCrypt Crew",
        hints: {
          create: [
            { content: "Read the challenge description carefully.", cost: 0, order: 0 },
            { content: `Focus on ${c.category.toLowerCase()} fundamentals.`, cost: 20, order: 1 }
          ]
        }
      }
    });
    challenges.push(created);
  }

  // --- Submissions + solves to populate a leaderboard ---
  // Deterministic pattern: earlier teams solve more challenges.
  for (let t = 0; t < teams.length; t++) {
    const { team, members } = teams[t];
    const solveCount = Math.max(3, 12 - t * 2);
    const captain = members[0];
    for (let i = 0; i < solveCount && i < challenges.length; i++) {
      const ch = challenges[i];
      await prisma.submission.create({
        data: {
          challengeId: ch.id,
          userId: captain.id,
          teamId: team.id,
          submitted: "ETHC{...}",
          correct: true
        }
      });
      await prisma.solve.create({
        data: {
          challengeId: ch.id,
          userId: captain.id,
          teamId: team.id,
          points: ch.points
        }
      });
    }
  }

  // --- Announcements (5) ---
  await prisma.announcement.createMany({
    data: [
      { title: "Registration is open", body: "Register your team for EthCrypt 2026 before the deadline.", pinned: true },
      { title: "Challenge categories announced", body: "Web, Crypto, Forensics, Pwn, Reversing and OSINT this year." },
      { title: "Keynote speaker confirmed", body: "Dr. Selam Abebe opens the symposium." },
      { title: "Scoring rules published", body: "Static scoring with manual judge adjustments where needed." },
      { title: "Venue details", body: "The CTF runs from the Computing Labs on the main campus." }
    ]
  });

  // --- Sponsors (4) ---
  await prisma.sponsor.createMany({
    data: [
      { name: "Dire Dawa University", tier: SponsorTier.PLATINUM, website: "https://ddu.edu.et" },
      { name: "INSA", tier: SponsorTier.GOLD, website: "https://insa.gov.et" },
      { name: "Ethio Telecom", tier: SponsorTier.SILVER },
      { name: "iceaddis", tier: SponsorTier.PARTNER }
    ]
  });

  // --- News (3) ---
  await prisma.newsPost.createMany({
    data: [
      { slug: "ethcrypt-2026-announced", title: "EthCrypt 2026 announced", excerpt: "The national challenge returns to Dire Dawa University.", body: "Full details of the 2026 symposium and CTF have been published.", category: "News", authorId: admin.id },
      { slug: "how-to-prepare", title: "How to prepare for the CTF", excerpt: "A starter guide for first-time competitors.", body: "Practice across web, crypto, forensics, pwn and reversing.", category: "Guides", authorId: judges[0].id },
      { slug: "2025-recap", title: "2025 in review", excerpt: "Highlights from the inaugural EthCrypt.", body: "Over 100 students competed in the first national event.", category: "Recap", authorId: admin.id }
    ]
  });

  await prisma.galleryItem.createMany({
    data: [
      { eventYear: 2025, caption: "Opening ceremony", mediaUrl: "https://images.unsplash.com/photo-1558494949-ef010cbdcc31" },
      { eventYear: 2025, caption: "Teams competing", mediaUrl: "https://images.unsplash.com/photo-1518770660439-4636190af475" }
    ]
  });

  console.log("Seed complete:");
  console.log(`  Admin login: ${adminEmail} / ${adminPassword}`);
  console.log("  Participant login: user1@student.ddu.edu.et / Password123!");
  console.log("  Judge login: judge1@ethcrypt.ddu.edu.et / Password123!");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
ETHCRYPT_HEREDOC_EOF

write 'public/favicon.svg' <<'ETHCRYPT_HEREDOC_EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <rect width="64" height="64" rx="12" fill="#0B1B3A"/>
  <path d="M32 10l16 6v12c0 12-8 20-16 24-8-4-16-12-16-24V16l16-6z" fill="none" stroke="#118A3D" stroke-width="3"/>
  <path d="M26 32l4 4 8-9" fill="none" stroke="#F5C518" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
ETHCRYPT_HEREDOC_EOF

write 'public/logo.svg' <<'ETHCRYPT_HEREDOC_EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <rect width="64" height="64" rx="12" fill="#0B1B3A"/>
  <path d="M32 10l16 6v12c0 12-8 20-16 24-8-4-16-12-16-24V16l16-6z" fill="none" stroke="#118A3D" stroke-width="3"/>
  <path d="M26 32l4 4 8-9" fill="none" stroke="#F5C518" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
ETHCRYPT_HEREDOC_EOF

write 'render.yaml' <<'ETHCRYPT_HEREDOC_EOF'
# Render Blueprint for EthCrypt
# Deploy: push to Git, then in Render → New → Blueprint, point at this repo.
databases:
  - name: ethcrypt-db
    databaseName: ethcrypt
    plan: free

services:
  - type: web
    name: ethcrypt-web
    runtime: node
    plan: free
    buildCommand: npm install && npx prisma generate && npx prisma db push --accept-data-loss && npm run build
    startCommand: npm start
    healthCheckPath: /api/health
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: ethcrypt-db
          property: connectionString
      - key: NEXTAUTH_SECRET
        generateValue: true
      - key: NEXTAUTH_URL
        sync: false
      - key: NEXT_PUBLIC_APP_URL
        sync: false
      - key: RESEND_API_KEY
        sync: false
      - key: EMAIL_FROM
        value: EthCrypt <no-reply@ethcrypt.ddu.edu.et>
      - key: CLOUDINARY_CLOUD_NAME
        sync: false
      - key: CLOUDINARY_API_KEY
        sync: false
      - key: CLOUDINARY_API_SECRET
        sync: false
      - key: ADMIN_EMAIL
        value: admin@ethcrypt.ddu.edu.et
      - key: ADMIN_PASSWORD
        sync: false
      - key: NODE_VERSION
        value: "20"
ETHCRYPT_HEREDOC_EOF

write 'tailwind.config.ts' <<'ETHCRYPT_HEREDOC_EOF'
import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./lib/**/*.{ts,tsx}"
  ],
  theme: {
    container: { center: true, padding: "1.5rem", screens: { "2xl": "1280px" } },
    extend: {
      colors: {
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))"
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))"
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))"
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))"
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))"
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))"
        },
        eth: {
          green: "#118A3D",
          yellow: "#F5C518",
          red: "#DA1212",
          navy: "#0B1B3A"
        }
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)"
      },
      fontFamily: {
        sans: ["var(--font-sans)", "system-ui", "sans-serif"],
        display: ["var(--font-display)", "Georgia", "serif"]
      },
      keyframes: {
        "fade-up": {
          from: { opacity: "0", transform: "translateY(12px)" },
          to: { opacity: "1", transform: "translateY(0)" }
        }
      },
      animation: { "fade-up": "fade-up 0.5s ease-out both" }
    }
  },
  plugins: []
};
export default config;
ETHCRYPT_HEREDOC_EOF

write 'tsconfig.json' <<'ETHCRYPT_HEREDOC_EOF'
{
  "compilerOptions": {
    "target": "ES2021",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
ETHCRYPT_HEREDOC_EOF

write 'types/index.ts' <<'ETHCRYPT_HEREDOC_EOF'
import type { ChallengeCategory } from "@prisma/client";

export type LeaderboardRow = {
  teamId: string;
  teamName: string;
  score: number;
  solves: number;
  rank: number;
};

export type PublicChallenge = {
  id: string;
  title: string;
  slug: string;
  category: ChallengeCategory;
  points: number;
  solves: number;
  locked: boolean;
};
ETHCRYPT_HEREDOC_EOF

write 'types/next-auth.d.ts' <<'ETHCRYPT_HEREDOC_EOF'
import type { Role } from "@prisma/client";
import type { DefaultSession } from "next-auth";

declare module "next-auth" {
  interface User {
    role: Role;
  }
  interface Session {
    user: {
      id: string;
      role: Role;
    } & DefaultSession["user"];
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    id: string;
    role: Role;
  }
}
ETHCRYPT_HEREDOC_EOF

# Include this generator inside the project for reference
cp "$0" "$ROOT/create-ethcrypt.sh" 2>/dev/null || true

echo "==> Zipping project -> ethcrypt.zip"
rm -f ethcrypt.zip
if command -v zip >/dev/null 2>&1; then
  zip -rq ethcrypt.zip "$ROOT" -x "*/node_modules/*" "*/.next/*"
else
  echo "!! zip not found; creating a tarball instead (ethcrypt.tar.gz)"
  tar -czf ethcrypt.tar.gz "$ROOT"
fi

echo "==> Done. Project tree:"
command -v tree >/dev/null 2>&1 && tree -a -I "node_modules|.next|.git" "$ROOT" || find "$ROOT" -type f -not -path "*/node_modules/*" | sort

cat <<"NEXT"

Next steps:
  cd ethcrypt
  cp .env.example .env      # set DATABASE_URL and NEXTAUTH_SECRET
  npm install
  npx prisma db push
  npm run db:seed
  npm run dev
NEXT
