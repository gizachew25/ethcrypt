import type { Metadata } from "next";
import { Inter, Sora } from "next/font/google";
import "./globals.css";
import { Providers } from "@/components/providers";

const inter = Inter({ subsets: ["latin"], variable: "--font-sans", display: "swap" });
const sora = Sora({ subsets: ["latin"], variable: "--font-display", display: "swap" });

const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";

export const metadata: Metadata = {
  metadataBase: new URL(appUrl),
  title: {
    default: "EthCrypt — Ethiopian Cyber Security Challenge",
    template: "%s · EthCrypt"
  },
  description:
    "The annual Ethiopian Cyber Security Challenge and symposium, hosted by Dire Dawa University. Register, compete in CTF challenges, and climb the leaderboard.",
  keywords: ["CTF", "cybersecurity", "Ethiopia", "Dire Dawa University", "EthCrypt"],
  openGraph: {
    title: "EthCrypt — Ethiopian Cyber Security Challenge",
    description: "Register, compete, and climb the leaderboard.",
    url: appUrl,
    siteName: "EthCrypt",
    type: "website"
  },
  robots: { index: true, follow: true }
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${inter.variable} ${sora.variable} font-sans antialiased`}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
