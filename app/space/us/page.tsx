"use client";
import { useSpace } from "@/app/space/space-shell";
export default function UsPage() { const { profile, partner } = useSpace(); return <main className="content"><p className="eyebrow">Us</p><h1>{partner ? `${profile?.display_name} & ${partner.display_name}` : "The two of you"}</h1><section className="section"><h2>Your story, at your pace.</h2><p>Add relationship details when you’re ready. Nothing is assumed here.</p></section></main>; }
