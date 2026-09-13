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
