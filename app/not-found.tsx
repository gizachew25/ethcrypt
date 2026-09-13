import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 text-center">
      <h1 className="font-display text-6xl font-bold text-accent">404</h1>
      <p className="text-muted-foreground">This page could not be found.</p>
      <Link href="/"><Button variant="accent">Back to home</Button></Link>
    </div>
  );
}
