// Email sender. Uses Resend when RESEND_API_KEY is set; otherwise logs to console.
// This keeps local dev and CI dependency-free while remaining production-ready.

type MailInput = { to: string; subject: string; html: string };

export async function sendMail({ to, subject, html }: MailInput): Promise<void> {
  const key = process.env.RESEND_API_KEY;
  const from = process.env.EMAIL_FROM ?? "EthCrypt <no-reply@ethcrypt.ddu.edu.et>";

  if (!key) {
    console.info(`[mail:dev] to=${to} subject="${subject}"`);
    return;
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ from, to, subject, html })
  });

  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`Resend failed (${res.status}): ${detail}`);
  }
}
