import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const base = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";
  const routes = ["", "/about", "/events", "/challenges", "/leaderboard", "/news", "/sponsors", "/contact", "/faq"];
  return routes.map((r) => ({ url: `${base}${r}`, lastModified: new Date() }));
}
