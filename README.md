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
