"use client";

import { useState } from "react";
import { Section } from "@/components/features/section";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Mail, MapPin } from "lucide-react";

export default function ContactPage() {
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("sending");
    setError(null);
    const form = new FormData(e.currentTarget);
    const payload = Object.fromEntries(form.entries());

    const res = await fetch("/api/contact", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });

    if (res.ok) {
      setStatus("sent");
      e.currentTarget.reset();
    } else {
      const data = await res.json().catch(() => ({}));
      setError(data.error ?? "Could not send your message. Try again.");
      setStatus("error");
    }
  }

  return (
    <Section title="Contact" subtitle="Questions about EthCrypt? Send us a message.">
      <div className="grid gap-8 lg:grid-cols-3">
        <div className="space-y-4 text-sm text-muted-foreground">
          <p className="flex items-center gap-2"><Mail className="h-4 w-4 text-accent" /> info@ethcrypt.ddu.edu.et</p>
          <p className="flex items-center gap-2"><MapPin className="h-4 w-4 text-accent" /> Dire Dawa University, Ethiopia</p>
        </div>
        <Card className="lg:col-span-2">
          <CardContent className="p-6">
            {status === "sent" ? (
              <p className="text-accent">Thanks — your message was received. We'll be in touch.</p>
            ) : (
              <form onSubmit={onSubmit} className="space-y-4">
                <div className="grid gap-4 sm:grid-cols-2">
                  <Input name="name" placeholder="Your name" required minLength={2} />
                  <Input name="email" type="email" placeholder="Email" required />
                </div>
                <Input name="subject" placeholder="Subject" required minLength={2} />
                <textarea
                  name="message"
                  placeholder="Your message"
                  required
                  minLength={10}
                  rows={5}
                  className="flex w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                />
                {error && <p className="text-sm text-destructive">{error}</p>}
                <Button type="submit" variant="accent" disabled={status === "sending"}>
                  {status === "sending" ? "Sending…" : "Send message"}
                </Button>
              </form>
            )}
          </CardContent>
        </Card>
      </div>
    </Section>
  );
}
