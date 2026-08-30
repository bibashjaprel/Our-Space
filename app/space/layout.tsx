import { createClient } from "@/app/utils/supabase/server";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { SpaceShell } from "@/app/space/space-shell";

export default async function SpaceLayout({ children }: { children: React.ReactNode }) {
  const supabase = createClient(await cookies());
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  return <SpaceShell userId={user.id} email={user.email ?? ""}>{children}</SpaceShell>;
}
