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
