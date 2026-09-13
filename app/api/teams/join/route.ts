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
