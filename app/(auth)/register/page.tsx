"use client";

import { useState } from "react";
import { signIn } from "next-auth/react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export default function RegisterPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const form = new FormData(e.currentTarget);
    const payload = Object.fromEntries(form.entries());

    const res = await fetch("/api/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });

    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      setError(data.error ?? "Registration failed.");
      setLoading(false);
      return;
    }

    await signIn("credentials", {
      email: String(payload.email),
      password: String(payload.password),
      redirect: false
    });
    router.push("/dashboard");
  }

  return (
    <Card>
      <CardHeader><CardTitle>Create your account</CardTitle></CardHeader>
      <CardContent>
        <form onSubmit={onSubmit} className="space-y-4">
          <Input name="name" placeholder="Full name" required minLength={2} />
          <Input name="email" type="email" placeholder="Email" required />
          <Input name="institution" placeholder="Institution (optional)" />
          <Input name="password" type="password" placeholder="Password (min 8 chars)" required minLength={8} />
          {error && <p className="text-sm text-destructive">{error}</p>}
          <Button type="submit" variant="accent" className="w-full" disabled={loading}>
            {loading ? "Creating…" : "Register"}
          </Button>
        </form>
        <p className="mt-4 text-center text-sm text-muted-foreground">
          Already have an account? <Link href="/login" className="text-accent hover:underline">Log in</Link>
        </p>
      </CardContent>
    </Card>
  );
}
