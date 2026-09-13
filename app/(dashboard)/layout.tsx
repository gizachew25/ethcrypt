import { Navbar } from "@/components/layout/navbar";

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col">
      <Navbar />
      <main className="container flex-1 py-10">{children}</main>
    </div>
  );
}
