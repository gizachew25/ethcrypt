import { Section } from "@/components/features/section";
import { Card, CardContent } from "@/components/ui/card";

export const metadata = { title: "About" };

export default function AboutPage() {
  const committee = [
    { name: "Dr. Selam Abebe", role: "Symposium Chair" },
    { name: "Yohannes Tesfaye", role: "CTF Lead" },
    { name: "DDU School of Computing", role: "Host" }
  ];
  return (
    <>
      <Section title="About EthCrypt" subtitle="Building Ethiopia's cybersecurity talent pipeline.">
        <div className="prose max-w-3xl text-muted-foreground">
          <p>
            EthCrypt is the Ethiopian Cyber Security Challenge, an annual symposium and
            capture-the-flag competition hosted by Dire Dawa University. It exists to grow
            practical security skills among students and professionals, and to connect them with
            industry and government partners.
          </p>
          <p className="mt-4">
            Since its 2024 pilot, the event has expanded into a national platform where teams
            compete across web, cryptography, forensics, binary exploitation, reverse engineering
            and OSINT.
          </p>
        </div>
      </Section>
      <Section title="Organizing committee">
        <div className="grid gap-6 md:grid-cols-3">
          {committee.map((m) => (
            <Card key={m.name}>
              <CardContent className="p-6">
                <h3 className="font-semibold">{m.name}</h3>
                <p className="text-sm text-muted-foreground">{m.role}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </Section>
    </>
  );
}
