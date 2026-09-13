"use client";

import { useEffect, useState } from "react";

function diff(target: number) {
  const total = Math.max(0, target - Date.now());
  return {
    days: Math.floor(total / 864e5),
    hours: Math.floor((total / 36e5) % 24),
    minutes: Math.floor((total / 6e4) % 60),
    seconds: Math.floor((total / 1e3) % 60)
  };
}

export function Countdown({ target }: { target: string }) {
  const t = new Date(target).getTime();
  const [time, setTime] = useState(() => diff(t));

  useEffect(() => {
    const id = setInterval(() => setTime(diff(t)), 1000);
    return () => clearInterval(id);
  }, [t]);

  const units: [string, number][] = [
    ["Days", time.days],
    ["Hours", time.hours],
    ["Minutes", time.minutes],
    ["Seconds", time.seconds]
  ];

  return (
    <div className="grid grid-cols-4 gap-3">
      {units.map(([label, value]) => (
        <div key={label} className="rounded-lg border bg-card/60 p-4 text-center backdrop-blur">
          <div className="font-display text-3xl font-bold tabular-nums text-accent md:text-4xl">
            {String(value).padStart(2, "0")}
          </div>
          <div className="mt-1 text-xs uppercase tracking-wide text-muted-foreground">{label}</div>
        </div>
      ))}
    </div>
  );
}
