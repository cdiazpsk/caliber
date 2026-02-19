import Link from "next/link";
import type { ReactNode } from "react";
import { createSupabaseServerClient } from "@/lib/supabase";
import SignOutButton from "@/components/sign-out-button";

export default async function ProtectedLayout({ children }: { children: ReactNode }) {
  const supabase = await createSupabaseServerClient();
  const { data: userData } = await supabase.auth.getUser();
  const user = userData.user;

  const { data: profile } = await supabase
    .from("profiles")
    .select("role, full_name")
    .eq("id", user?.id)
    .maybeSingle();

  return (
    <main className="container" style={{ display: "grid", gap: 12 }}>
      <header className="card row" style={{ justifyContent: "space-between" }}>
        <div className="row">
          <Link href="/work-orders">Work Orders</Link>
          {profile?.role === "admin" ? <Link href="/admin/assignments">PM Assignments</Link> : null}
        </div>
        <div className="row">
          <small>
            {profile?.full_name ?? user?.email} ({profile?.role ?? "unknown"})
          </small>
          <SignOutButton />
        </div>
      </header>
      {children}
    </main>
  );
}
