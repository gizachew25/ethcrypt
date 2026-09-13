import { redirect } from "next/navigation";
import { requireRole } from "@/lib/session";
import { Navbar } from "@/components/layout/navbar";

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const user = await requireRole("ADMIN", "JUDGE");
  if (!user) redirect("/dashboard");
  return (
    <div className="flex min-h-screen flex-col">
      <Navbar />
      <main className="container flex-1 py-10">{children}</main>
    </div>
  );
}
