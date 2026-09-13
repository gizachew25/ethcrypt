import { computeLeaderboard } from "@/lib/scoring";
import { ok } from "@/lib/api";

export const dynamic = "force-dynamic";

export async function GET() {
  const rows = await computeLeaderboard();
  return ok({ leaderboard: rows });
}
