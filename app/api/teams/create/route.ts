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
