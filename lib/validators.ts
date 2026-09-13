import { z } from "zod";

export const registerSchema = z.object({
  name: z.string().min(2, "Name is too short").max(80),
  email: z.string().email("Enter a valid email"),
  password: z.string().min(8, "Use at least 8 characters").max(100),
  institution: z.string().max(120).optional()
});
export type RegisterInput = z.infer<typeof registerSchema>;

export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1)
});

export const contactSchema = z.object({
  name: z.string().min(2).max(80),
  email: z.string().email(),
  subject: z.string().min(2).max(120),
  message: z.string().min(10).max(2000)
});
export type ContactInput = z.infer<typeof contactSchema>;

export const flagSubmissionSchema = z.object({
  challengeId: z.string().min(1),
  flag: z.string().min(1).max(200)
});

export const teamCreateSchema = z.object({
  name: z.string().min(2).max(60),
  institution: z.string().max(120).optional()
});

export const teamJoinSchema = z.object({
  inviteCode: z.string().min(4).max(16)
});

export const challengeSchema = z.object({
  eventId: z.string().min(1),
  title: z.string().min(2).max(120),
  category: z.enum([
    "WEB",
    "CRYPTO",
    "FORENSICS",
    "PWN",
    "REVERSING",
    "OSINT",
    "MISC"
  ]),
  description: z.string().min(10),
  points: z.number().int().min(1).max(1000),
  flag: z.string().min(1),
  published: z.boolean().optional()
});
