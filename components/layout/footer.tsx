import Link from "next/link";
import { Shield } from "lucide-react";

export function Footer() {
  return (
    <footer className="border-t bg-card">
      <div className="eth-stripe h-1 w-full" />
      <div className="container grid gap-8 py-12 md:grid-cols-4">
        <div className="space-y-2">
          <div className="flex items-center gap-2 font-display text-lg font-bold">
            <Shield className="h-5 w-5 text-accent" /> EthCrypt
          </div>
          <p className="text-sm text-muted-foreground">
            Ethiopian Cyber Security Challenge, hosted by Dire Dawa University.
          </p>
        </div>
        <div>
          <h4 className="mb-3 text-sm font-semibold">Platform</h4>
          <ul className="space-y-2 text-sm text-muted-foreground">
            <li><Link href="/challenges" className="hover:text-foreground">Challenges</Link></li>
            <li><Link href="/leaderboard" className="hover:text-foreground">Leaderboard</Link></li>
            <li><Link href="/events" className="hover:text-foreground">Events</Link></li>
          </ul>
        </div>
        <div>
          <h4 className="mb-3 text-sm font-semibold">Organization</h4>
          <ul className="space-y-2 text-sm text-muted-foreground">
            <li><Link href="/about" className="hover:text-foreground">About</Link></li>
            <li><Link href="/sponsors" className="hover:text-foreground">Sponsors</Link></li>
            <li><Link href="/contact" className="hover:text-foreground">Contact</Link></li>
          </ul>
        </div>
        <div>
          <h4 className="mb-3 text-sm font-semibold">Legal</h4>
          <ul className="space-y-2 text-sm text-muted-foreground">
            <li><Link href="/faq" className="hover:text-foreground">FAQ</Link></li>
            <li><Link href="/faq#terms" className="hover:text-foreground">Terms</Link></li>
            <li><Link href="/faq#privacy" className="hover:text-foreground">Privacy</Link></li>
          </ul>
        </div>
      </div>
      <div className="border-t py-6 text-center text-sm text-muted-foreground">
        © {new Date().getFullYear()} EthCrypt — Dire Dawa University. All rights reserved.
      </div>
    </footer>
  );
}
