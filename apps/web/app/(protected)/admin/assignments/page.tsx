import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase";

export default async function AssignmentsPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: me } = await supabase
    .from("profiles")
    .select("id, role")
    .eq("id", user?.id)
    .single();

  if (me?.role !== "admin") {
    redirect("/work-orders");
  }

  const [{ data: pms }, { data: techs }, { data: assignments }] = await Promise.all([
    supabase.from("profiles").select("id, full_name").eq("role", "pm").order("full_name"),
    supabase.from("profiles").select("id, full_name").eq("role", "tech").order("full_name"),
    supabase.from("pm_tech_map").select("pm_id, tech_id").order("pm_id").order("tech_id"),
  ]);

  async function createAssignment(formData: FormData) {
    "use server";

    const pmId = String(formData.get("pm_id") || "");
    const techId = String(formData.get("tech_id") || "");

    const serverSupabase = await createSupabaseServerClient();
    await serverSupabase.from("pm_tech_map").insert({ pm_id: pmId, tech_id: techId });
    revalidatePath("/admin/assignments");
  }

  async function deleteAssignment(formData: FormData) {
    "use server";

    const pmId = String(formData.get("pm_id") || "");
    const techId = String(formData.get("tech_id") || "");

    const serverSupabase = await createSupabaseServerClient();
    await serverSupabase.from("pm_tech_map").delete().eq("pm_id", pmId).eq("tech_id", techId);
    revalidatePath("/admin/assignments");
  }

  return (
    <section className="card" style={{ display: "grid", gap: 12 }}>
      <h1>PM → Tech Assignments (Admin only)</h1>

      <form action={createAssignment} className="row">
        <select name="pm_id" required defaultValue="">
          <option value="" disabled>
            Select PM
          </option>
          {pms?.map((pm) => (
            <option key={pm.id} value={pm.id}>
              {pm.full_name ?? pm.id}
            </option>
          ))}
        </select>

        <select name="tech_id" required defaultValue="">
          <option value="" disabled>
            Select Tech
          </option>
          {techs?.map((tech) => (
            <option key={tech.id} value={tech.id}>
              {tech.full_name ?? tech.id}
            </option>
          ))}
        </select>

        <button type="submit">Add mapping</button>
      </form>

      <table>
        <thead>
          <tr>
            <th>PM</th>
            <th>Technician</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {assignments?.map((mapping) => (
            <tr key={`${mapping.pm_id}-${mapping.tech_id}`}>
              <td>{mapping.pm_id}</td>
              <td>{mapping.tech_id}</td>
              <td>
                <form action={deleteAssignment}>
                  <input type="hidden" name="pm_id" value={mapping.pm_id} />
                  <input type="hidden" name="tech_id" value={mapping.tech_id} />
                  <button type="submit">Delete</button>
                </form>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
