import bcrypt from "bcryptjs";
import { prisma } from "@/lib/prisma";
import { registerSchema } from "@/lib/validators";
import { ok, fail, handleZod } from "@/lib/api";
import { rateLimit, clientKey } from "@/lib/rate-limit";
import { sendMail } from "@/lib/mail";

export async function POST(req: Request) {
  const limit = rateLimit(clientKey(req, "register"), 5, 60_000);
  if (!limit.ok) return fail("Too many attempts. Try again shortly.", 429);

  try {
    const body = registerSchema.parse(await req.json());
    const existing = await prisma.user.findUnique({ where: { email: body.email } });
    if (existing) return fail("An account with that email already exists.", 409);

    const user = await prisma.user.create({
      data: {
        name: body.name,
        email: body.email,
        institution: body.institution,
        passwordHash: await bcrypt.hash(body.password, 10)
      },
      select: { id: true, email: true, name: true }
    });

    await sendMail({
      to: user.email,
      subject: "Welcome to EthCrypt",
      html: `<p>Hi ${user.name}, your EthCrypt account is ready. Log in to form a team and start solving.</p>`
    }).catch(() => undefined);

    return ok({ user }, 201);
  } catch (err) {
    return handleZod(err);
  }
}
