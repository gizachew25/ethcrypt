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
