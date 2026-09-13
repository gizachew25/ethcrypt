import Link from "next/link";
import { Shield } from "lucide-react";

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-background px-6">
      <Link href="/" className="mb-8 flex items-center gap-2 font-display text-2xl font-bold">
        <Shield className="h-7 w-7 text-accent" /> EthCrypt
      </Link>
      <div className="w-full max-w-md">{children}</div>
    </div>
  );
}
