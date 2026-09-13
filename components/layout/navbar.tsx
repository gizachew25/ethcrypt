"use client";

import Link from "next/link";
import { useSession, signOut } from "next-auth/react";
import { Shield, Menu, X } from "lucide-react";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { ThemeToggle } from "@/components/layout/theme-toggle";

const links = [
  { href: "/about", label: "About" },
  { href: "/events", label: "Events" },
  { href: "/challenges", label: "Challenges" },
  { href: "/leaderboard", label: "Leaderboard" },
  { href: "/news", label: "News" },
  { href: "/sponsors", label: "Sponsors" },
  { href: "/contact", label: "Contact" }
];

export function Navbar() {
  const { data: session } = useSession();
  const [open, setOpen] = useState(false);

  return (
    <header className="sticky top-0 z-40 w-full border-b bg-background/80 backdrop-blur">
      <div className="eth-stripe h-1 w-full" />
      <div className="container flex h-16 items-center justify-between">
        <Link href="/" className="flex items-center gap-2 font-display text-lg font-bold">
          <Shield className="h-6 w-6 text-accent" />
          EthCrypt
        </Link>

        <nav className="hidden items-center gap-6 md:flex">
          {links.map((l) => (
            <Link key={l.href} href={l.href} className="text-sm text-muted-foreground hover:text-foreground">
              {l.label}
            </Link>
          ))}
        </nav>

        <div className="hidden items-center gap-2 md:flex">
          <ThemeToggle />
          {session ? (
            <>
              {(session.user.role === "ADMIN" || session.user.role === "JUDGE") && (
                <Link href="/admin"><Button variant="outline" size="sm">Admin</Button></Link>
              )}
              <Link href="/dashboard"><Button variant="outline" size="sm">Dashboard</Button></Link>
              <Button size="sm" onClick={() => signOut({ callbackUrl: "/" })}>Sign out</Button>
            </>
          ) : (
            <>
              <Link href="/login"><Button variant="outline" size="sm">Log in</Button></Link>
              <Link href="/register"><Button variant="accent" size="sm">Register</Button></Link>
            </>
          )}
        </div>

        <div className="flex items-center gap-1 md:hidden">
          <ThemeToggle />
          <Button variant="ghost" size="icon" aria-label="Menu" onClick={() => setOpen(!open)}>
            {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
          </Button>
        </div>
      </div>

      {open && (
        <div className="border-t px-6 py-4 md:hidden">
          <nav className="flex flex-col gap-3">
            {links.map((l) => (
              <Link key={l.href} href={l.href} onClick={() => setOpen(false)} className="text-sm text-muted-foreground hover:text-foreground">
                {l.label}
              </Link>
            ))}
            <div className="mt-2 flex gap-2">
              {session ? (
                <Button size="sm" onClick={() => signOut({ callbackUrl: "/" })}>Sign out</Button>
              ) : (
                <>
                  <Link href="/login" className="flex-1"><Button variant="outline" size="sm" className="w-full">Log in</Button></Link>
                  <Link href="/register" className="flex-1"><Button variant="accent" size="sm" className="w-full">Register</Button></Link>
                </>
              )}
            </div>
          </nav>
        </div>
      )}
    </header>
  );
}
