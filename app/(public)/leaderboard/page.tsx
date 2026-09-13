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
