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
