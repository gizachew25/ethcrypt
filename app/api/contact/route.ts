import { prisma } from "@/lib/prisma";
import { contactSchema } from "@/lib/validators";
import { ok, fail, handleZod } from "@/lib/api";
import { rateLimit, clientKey } from "@/lib/rate-limit";
import { sendMail } from "@/lib/mail";

export async function POST(req: Request) {
  const limit = rateLimit(clientKey(req, "contact"), 5, 60_000);
  if (!limit.ok) return fail("Too many messages. Try again shortly.", 429);

  try {
    const body = contactSchema.parse(await req.json());
    const message = await prisma.contactMessage.create({ data: body });

    const admin = process.env.ADMIN_EMAIL;
    if (admin) {
      await sendMail({
        to: admin,
        subject: `Contact: ${body.subject}`,
        html: `<p>From ${body.name} (${body.email}):</p><p>${body.message}</p>`
      }).catch(() => undefined);
    }

    return ok({ id: message.id }, 201);
  } catch (err) {
    return handleZod(err);
  }
}
