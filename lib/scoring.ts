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
