import { Section } from "@/components/features/section";
import { Card, CardContent } from "@/components/ui/card";

export const metadata = { title: "FAQ, Terms & Privacy" };

const faqs = [
  { q: "Who can participate?", a: "Students, professionals and cybersecurity enthusiasts. Teams of up to five compete in the CTF." },
  { q: "How do I register?", a: "Create an account, then create or join a team using an invite code." },
  { q: "How is scoring calculated?", a: "Static points per challenge, awarded on first correct flag per team, with manual judge adjustments where needed." },
  { q: "Is the leaderboard public?", a: "Yes, the leaderboard is read-only and public. It may be frozen near the end of the event." }
];

export default function FaqPage() {
  return (
    <>
      <Section title="Frequently asked questions">
        <div className="space-y-4">
          {faqs.map((f) => (
            <Card key={f.q}>
              <CardContent className="p-6">
                <h3 className="mb-1 font-semibold">{f.q}</h3>
                <p className="text-sm text-muted-foreground">{f.a}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </Section>
      <Section title="Terms of use" className="pt-0">
        <p id="terms" className="max-w-3xl text-sm text-muted-foreground">
          By participating you agree to compete fairly, not to attack the scoring
          infrastructure, and to follow the code of conduct. Violations may result in
          disqualification at the judges' discretion.
        </p>
      </Section>
      <Section title="Privacy policy" className="pt-0">
        <p id="privacy" className="max-w-3xl text-sm text-muted-foreground">
          We store the account and team data you provide to run the competition. Contact
          messages are stored to respond to your enquiry. We do not sell personal data.
        </p>
      </Section>
    </>
  );
}
