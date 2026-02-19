"use client";

import { createSupabaseBrowserClient } from "@/lib/supabase";

export default function SignOutButton() {
  async function onSignOut() {
    const supabase = createSupabaseBrowserClient();
    await supabase.auth.signOut();
    window.location.href = "/sign-in";
  }

  return <button onClick={onSignOut}>Sign out</button>;
}
