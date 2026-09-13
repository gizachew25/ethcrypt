import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";
import crypto from "crypto";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function hashFlag(flag: string): string {
  return crypto.createHash("sha256").update(flag.trim()).digest("hex");
}

export function verifyFlag(flag: string, hash: string): boolean {
  const candidate = hashFlag(flag);
  const a = Buffer.from(candidate);
  const b = Buffer.from(hash);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

export function inviteCode(): string {
  return crypto.randomBytes(4).toString("hex").toUpperCase();
}

export function certificateCode(): string {
  return "ETHC-" + crypto.randomBytes(5).toString("hex").toUpperCase();
}

export function formatDate(d: Date | string): string {
  return new Date(d).toLocaleDateString("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric"
  });
}
