import { PrismaClient, ChallengeCategory, Role, SponsorTier } from "@prisma/client";
import bcrypt from "bcryptjs";
import crypto from "crypto";

const prisma = new PrismaClient();

const hashFlag = (f: string) =>
  crypto.createHash("sha256").update(f.trim()).digest("hex");
const invite = () => crypto.randomBytes(4).toString("hex").toUpperCase();
const slugify = (s: string) =>
  s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");

async function main() {
  console.log("Seeding EthCrypt…");

  // --- wipe (dev/demo only) ---
  await prisma.$transaction([
    prisma.solve.deleteMany(),
    prisma.submission.deleteMany(),
    prisma.hint.deleteMany(),
    prisma.challenge.deleteMany(),
    prisma.scheduleItem.deleteMany(),
    prisma.certificate.deleteMany(),
    prisma.auditLog.deleteMany(),
    prisma.newsPost.deleteMany(),
    prisma.announcement.deleteMany(),
    prisma.sponsor.deleteMany(),
    prisma.contactMessage.deleteMany(),
    prisma.galleryItem.deleteMany(),
    prisma.scoreAdjustment.deleteMany()
  ]);
  // Detach members before deleting teams/users
  await prisma.user.updateMany({ data: { teamId: null } });
  await prisma.team.deleteMany();
  await prisma.user.deleteMany();

  const adminEmail = process.env.ADMIN_EMAIL ?? "admin@ethcrypt.ddu.edu.et";
  const adminPassword = process.env.ADMIN_PASSWORD ?? "ChangeMe123!";

  // --- Users ---
  const admin = await prisma.user.create({
    data: {
      name: "EthCrypt Admin",
      email: adminEmail,
      role: Role.ADMIN,
      institution: "Dire Dawa University",
      passwordHash: await bcrypt.hash(adminPassword, 10)
    }
  });

  const commonHash = await bcrypt.hash("Password123!", 10);

  const judges = await Promise.all(
    ["Selam Abebe", "Yohannes Tesfaye"].map((name, i) =>
      prisma.user.create({
        data: {
          name,
          email: `judge${i + 1}@ethcrypt.ddu.edu.et`,
          role: Role.JUDGE,
          institution: "Dire Dawa University",
          passwordHash: commonHash
        }
      })
    )
  );

  const firstNames = [
    "Abel", "Bethlehem", "Dawit", "Eden", "Feven", "Girma", "Hana", "Ibrahim",
    "Kalkidan", "Liya", "Mekdes", "Nahom", "Robel", "Saba", "Tewodros",
    "Winta", "Yared", "Zufan", "Amanuel", "Bezawit"
  ];
  const participants = await Promise.all(
    firstNames.map((name, i) =>
      prisma.user.create({
        data: {
          name,
          email: `user${i + 1}@student.ddu.edu.et`,
          role: Role.PARTICIPANT,
          institution: "Dire Dawa University",
          passwordHash: commonHash
        }
      })
    )
  );

  // --- Events ---
  const now = new Date();
  const currentEvent = await prisma.event.create({
    data: {
      slug: "ethcrypt-2026",
      title: "EthCrypt Symposium 2026",
      year: 2026,
      description:
        "The annual Ethiopian Cyber Security Challenge hosted by Dire Dawa University — a two-day symposium and CTF bringing together students, researchers and industry.",
      location: "Dire Dawa University, Main Campus",
      startsAt: new Date(now.getTime() + 30 * 864e5),
      endsAt: new Date(now.getTime() + 32 * 864e5),
      isCurrent: true
    }
  });

  await prisma.event.createMany({
    data: [
      {
        slug: "ethcrypt-2025",
        title: "EthCrypt Symposium 2025",
        year: 2025,
        description: "The inaugural national cybersecurity challenge and symposium.",
        location: "Dire Dawa University",
        startsAt: new Date("2025-05-10"),
        endsAt: new Date("2025-05-11")
      },
      {
        slug: "ethcrypt-2024",
        title: "EthCrypt Pilot 2024",
        year: 2024,
        description: "A regional pilot event that seeded the national challenge.",
        location: "Dire Dawa",
        startsAt: new Date("2024-06-01"),
        endsAt: new Date("2024-06-01")
      }
    ]
  });

  await prisma.scheduleItem.createMany({
    data: [
      {
        eventId: currentEvent.id,
        title: "Opening keynote: The state of cyber in the Horn of Africa",
        speaker: "Dr. Selam Abebe",
        startsAt: new Date(now.getTime() + 30 * 864e5 + 9 * 36e5),
        endsAt: new Date(now.getTime() + 30 * 864e5 + 10 * 36e5),
        location: "Main Auditorium"
      },
      {
        eventId: currentEvent.id,
        title: "CTF competition begins",
        speaker: null,
        startsAt: new Date(now.getTime() + 30 * 864e5 + 11 * 36e5),
        endsAt: new Date(now.getTime() + 31 * 864e5 + 11 * 36e5),
        location: "Computing Labs"
      }
    ]
  });

  // --- Teams (6), assign participants, first member is captain ---
  const teamNames = [
    "Nyala Defenders",
    "Addis Overflow",
    "Rift Valley Root",
    "Sheba Shellcode",
    "Blue Nile Bytes",
    "Harar Hashcats"
  ];
  const teams = [];
  for (let t = 0; t < teamNames.length; t++) {
    const members = participants.slice(t * 3, t * 3 + 3);
    const team = await prisma.team.create({
      data: {
        name: teamNames[t],
        inviteCode: invite(),
        approved: true,
        institution: "Dire Dawa University",
        eventId: currentEvent.id,
        captainId: members[0]?.id,
        members: { connect: members.map((m) => ({ id: m.id })) }
      }
    });
    teams.push({ team, members });
  }

  // --- Challenges (15) ---
  const challengeDefs: {
    title: string;
    category: ChallengeCategory;
    points: number;
    flag: string;
    description: string;
  }[] = [
    { title: "Cookie Monster", category: ChallengeCategory.WEB, points: 100, flag: "ETHC{tamper_the_cookie}", description: "A login form trusts a client-side cookie a little too much." },
    { title: "SQL Safari", category: ChallengeCategory.WEB, points: 200, flag: "ETHC{union_based_win}", description: "Find the flag hidden behind an injectable search box." },
    { title: "JWT None", category: ChallengeCategory.WEB, points: 250, flag: "ETHC{alg_none_bypass}", description: "The API validates tokens, but does it validate the algorithm?" },
    { title: "XOR Me Not", category: ChallengeCategory.CRYPTO, points: 150, flag: "ETHC{single_byte_xor}", description: "A message encrypted with a one-byte key. Recover it." },
    { title: "RSA Rookie", category: ChallengeCategory.CRYPTO, points: 200, flag: "ETHC{small_e_attack}", description: "Textbook RSA with a very small exponent." },
    { title: "Padding Party", category: ChallengeCategory.CRYPTO, points: 300, flag: "ETHC{padding_oracle}", description: "A padding oracle leaks one byte at a time." },
    { title: "Deleted But Not Gone", category: ChallengeCategory.FORENSICS, points: 150, flag: "ETHC{carve_the_jpeg}", description: "Recover a file that was deleted from this disk image." },
    { title: "Packet Whisperer", category: ChallengeCategory.FORENSICS, points: 200, flag: "ETHC{follow_the_stream}", description: "The flag was exfiltrated over the network. Find it in the pcap." },
    { title: "Stego Sunset", category: ChallengeCategory.FORENSICS, points: 250, flag: "ETHC{lsb_in_the_pixels}", description: "This sunset photo hides more than colors." },
    { title: "Baby Overflow", category: ChallengeCategory.PWN, points: 200, flag: "ETHC{smashed_the_stack}", description: "A classic stack buffer overflow to redirect execution." },
    { title: "Format Fun", category: ChallengeCategory.PWN, points: 300, flag: "ETHC{printf_leak}", description: "An uncontrolled format string leaks and writes memory." },
    { title: "Crackme Zero", category: ChallengeCategory.REVERSING, points: 150, flag: "ETHC{static_strings}", description: "Reverse a small binary to find the accepted password." },
    { title: "VM Riddle", category: ChallengeCategory.REVERSING, points: 350, flag: "ETHC{custom_bytecode}", description: "A tiny custom virtual machine guards the flag." },
    { title: "Find The Founder", category: ChallengeCategory.OSINT, points: 100, flag: "ETHC{open_source_intel}", description: "Use public sources to identify the account behind the leak." },
    { title: "Geoguess DDU", category: ChallengeCategory.OSINT, points: 150, flag: "ETHC{pin_the_campus}", description: "Locate exactly where on campus this photo was taken." }
  ];

  const challenges = [];
  for (const c of challengeDefs) {
    const created = await prisma.challenge.create({
      data: {
        eventId: currentEvent.id,
        title: c.title,
        slug: slugify(c.title),
        category: c.category,
        description: c.description,
        points: c.points,
        flagHash: hashFlag(c.flag),
        published: true,
        authorName: "EthCrypt Crew",
        hints: {
          create: [
            { content: "Read the challenge description carefully.", cost: 0, order: 0 },
            { content: `Focus on ${c.category.toLowerCase()} fundamentals.`, cost: 20, order: 1 }
          ]
        }
      }
    });
    challenges.push(created);
  }

  // --- Submissions + solves to populate a leaderboard ---
  // Deterministic pattern: earlier teams solve more challenges.
  for (let t = 0; t < teams.length; t++) {
    const { team, members } = teams[t];
    const solveCount = Math.max(3, 12 - t * 2);
    const captain = members[0];
    for (let i = 0; i < solveCount && i < challenges.length; i++) {
      const ch = challenges[i];
      await prisma.submission.create({
        data: {
          challengeId: ch.id,
          userId: captain.id,
          teamId: team.id,
          submitted: "ETHC{...}",
          correct: true
        }
      });
      await prisma.solve.create({
        data: {
          challengeId: ch.id,
          userId: captain.id,
          teamId: team.id,
          points: ch.points
        }
      });
    }
  }

  // --- Announcements (5) ---
  await prisma.announcement.createMany({
    data: [
      { title: "Registration is open", body: "Register your team for EthCrypt 2026 before the deadline.", pinned: true },
      { title: "Challenge categories announced", body: "Web, Crypto, Forensics, Pwn, Reversing and OSINT this year." },
      { title: "Keynote speaker confirmed", body: "Dr. Selam Abebe opens the symposium." },
      { title: "Scoring rules published", body: "Static scoring with manual judge adjustments where needed." },
      { title: "Venue details", body: "The CTF runs from the Computing Labs on the main campus." }
    ]
  });

  // --- Sponsors (4) ---
  await prisma.sponsor.createMany({
    data: [
      { name: "Dire Dawa University", tier: SponsorTier.PLATINUM, website: "https://ddu.edu.et" },
      { name: "INSA", tier: SponsorTier.GOLD, website: "https://insa.gov.et" },
      { name: "Ethio Telecom", tier: SponsorTier.SILVER },
      { name: "iceaddis", tier: SponsorTier.PARTNER }
    ]
  });

  // --- News (3) ---
  await prisma.newsPost.createMany({
    data: [
      { slug: "ethcrypt-2026-announced", title: "EthCrypt 2026 announced", excerpt: "The national challenge returns to Dire Dawa University.", body: "Full details of the 2026 symposium and CTF have been published.", category: "News", authorId: admin.id },
      { slug: "how-to-prepare", title: "How to prepare for the CTF", excerpt: "A starter guide for first-time competitors.", body: "Practice across web, crypto, forensics, pwn and reversing.", category: "Guides", authorId: judges[0].id },
      { slug: "2025-recap", title: "2025 in review", excerpt: "Highlights from the inaugural EthCrypt.", body: "Over 100 students competed in the first national event.", category: "Recap", authorId: admin.id }
    ]
  });

  await prisma.galleryItem.createMany({
    data: [
      { eventYear: 2025, caption: "Opening ceremony", mediaUrl: "https://images.unsplash.com/photo-1558494949-ef010cbdcc31" },
      { eventYear: 2025, caption: "Teams competing", mediaUrl: "https://images.unsplash.com/photo-1518770660439-4636190af475" }
    ]
  });

  console.log("Seed complete:");
  console.log(`  Admin login: ${adminEmail} / ${adminPassword}`);
  console.log("  Participant login: user1@student.ddu.edu.et / Password123!");
  console.log("  Judge login: judge1@ethcrypt.ddu.edu.et / Password123!");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
