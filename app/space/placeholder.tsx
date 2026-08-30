"use client";
export function Placeholder({ title, description }: { title: string; description: string }) { return <main className="content"><p className="eyebrow">Our Space</p><h1>{title}</h1><section className="section"><h2>Coming soon</h2><p>{description}</p></section></main>; }
