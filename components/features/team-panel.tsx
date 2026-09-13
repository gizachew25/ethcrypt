"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Copy, Users } from "lucide-react";

type Team = { id: string; name: string; inviteCode: string; approved: boolean } | null;

export function TeamPanel({ team }: { team: Team }) {
  const router = useRouter();
  const [name, setName] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function call(path: string, body: object) {
    setLoading(true);
    setError(null);
    const res = await fetch(path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });
    setLoading(false);
    if (res.ok) router.refresh();
    else {
      const data = await res.json().catch(() => ({}));
      setError(data.error ?? "Request failed.");
    }
  }

  if (team) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Users className="h-5 w-5 text-accent" /> {team.name}
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            Invite teammates with this code:
          </p>
          <div className="mt-2 flex items-center gap-2">
            <code className="rounded bg-secondary px-3 py-1 font-mono text-sm">{team.inviteCode}</code>
            <Button
              size="sm"
              variant="ghost"
              onClick={() => navigator.clipboard.writeText(team.inviteCode)}
              aria-label="Copy invite code"
            >
              <Copy className="h-4 w-4" />
            </Button>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader><CardTitle>Your team</CardTitle></CardHeader>
      <CardContent className="grid gap-6 md:grid-cols-2">
        <div className="space-y-2">
          <p className="text-sm font-medium">Create a team</p>
          <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Team name" />
          <Button variant="accent" disabled={loading || name.length < 2} onClick={() => call("/api/teams/create", { name })}>
            Create
          </Button>
        </div>
        <div className="space-y-2">
          <p className="text-sm font-medium">Join with a code</p>
          <Input value={code} onChange={(e) => setCode(e.target.value)} placeholder="Invite code" className="font-mono" />
          <Button variant="outline" disabled={loading || code.length < 4} onClick={() => call("/api/teams/join", { inviteCode: code })}>
            Join
          </Button>
        </div>
        {error && <p className="text-sm text-destructive md:col-span-2">{error}</p>}
      </CardContent>
    </Card>
  );
}
