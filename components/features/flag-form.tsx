"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export function FlagForm({ challengeId, solved }: { challengeId: string; solved: boolean }) {
  const router = useRouter();
  const [flag, setFlag] = useState("");
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [loading, setLoading] = useState(false);

  if (solved) return <p className="text-sm font-medium text-accent">Solved ✓</p>;

  async function submit() {
    setLoading(true);
    setMsg(null);
    const res = await fetch("/api/submissions", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ challengeId, flag })
    });
    const data = await res.json().catch(() => ({}));
    setLoading(false);

    if (res.ok && data.correct) {
      setMsg({ ok: true, text: "Correct flag — points awarded." });
      setFlag("");
      router.refresh();
    } else if (res.ok) {
      setMsg({ ok: false, text: "Incorrect flag. Try again." });
    } else {
      setMsg({ ok: false, text: data.error ?? "Submission failed." });
    }
  }

  return (
    <div className="space-y-2">
      <div className="flex gap-2">
        <Input
          value={flag}
          onChange={(e) => setFlag(e.target.value)}
          placeholder="ETHC{...}"
          className="font-mono"
        />
        <Button variant="accent" onClick={submit} disabled={loading || flag.length === 0}>
          {loading ? "…" : "Submit"}
        </Button>
      </div>
      {msg && <p className={msg.ok ? "text-sm text-accent" : "text-sm text-destructive"}>{msg.text}</p>}
    </div>
  );
}
