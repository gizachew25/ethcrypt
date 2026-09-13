import { prisma } from "@/lib/prisma";
import { Section } from "@/components/features/section";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { formatDate } from "@/lib/utils";

export const metadata = { title: "News & Announcements" };
export const dynamic = "force-dynamic";

export default async function NewsPage() {
  const [posts, announcements] = await Promise.all([
    prisma.newsPost.findMany({ where: { published: true }, orderBy: { createdAt: "desc" } }),
    prisma.announcement.findMany({ orderBy: [{ pinned: "desc" }, { createdAt: "desc" }] })
  ]);

  return (
    <>
      <Section title="Announcements">
        {announcements.length === 0 ? (
          <p className="text-muted-foreground">No announcements yet.</p>
        ) : (
          <div className="space-y-3">
            {announcements.map((a) => (
              <Card key={a.id}>
                <CardContent className="flex items-start justify-between gap-4 p-4">
                  <div>
                    <h3 className="font-semibold">{a.title}</h3>
                    <p className="text-sm text-muted-foreground">{a.body}</p>
                  </div>
                  {a.pinned && <Badge variant="accent">Pinned</Badge>}
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </Section>
      <Section title="News">
        <div className="grid gap-6 md:grid-cols-3">
          {posts.map((p) => (
            <Card key={p.id}>
              <CardContent className="p-6">
                <Badge className="mb-2">{p.category}</Badge>
                <h3 className="mb-1 font-semibold">{p.title}</h3>
                <p className="text-sm text-muted-foreground">{p.excerpt}</p>
                <p className="mt-3 text-xs text-muted-foreground">{formatDate(p.createdAt)}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </Section>
    </>
  );
}
