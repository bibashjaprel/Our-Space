import { createClient } from "@/app/utils/supabase/server";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";

export default async function AuthLayout({ children }: { children: React.ReactNode }) {
  const supabase = createClient(await cookies());
  const { data: { user } } = await supabase.auth.getUser();
  if (user) redirect("/space");
  return children;
}
