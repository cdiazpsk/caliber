import Link from "next/link";
import { createSupabaseServerClient } from "@/lib/supabase";

type SearchParams = {
  status?: string;
  priority?: string;
  property?: string;
  technician?: string;
};

export default async function WorkOrdersPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: me } = await supabase
    .from("profiles")
    .select("id, role")
    .eq("id", user?.id)
    .single();

  let query = supabase
    .from("work_orders")
    .select("id,title,status,priority,property_id,technician_id,updated_at")
    .order("updated_at", { ascending: false });

  if (searchParams.status) query = query.eq("status", searchParams.status);
  if (searchParams.priority) query = query.eq("priority", searchParams.priority);
  if (searchParams.property) query = query.eq("property_id", searchParams.property);

  const canFilterTechnician = me?.role === "admin" || me?.role === "pm";
  if (canFilterTechnician && searchParams.technician) {
    query = query.eq("technician_id", searchParams.technician);
  }

  const { data: workOrders } = await query;

  const { data: techOptions } = canFilterTechnician
    ? await supabase
        .from("profiles")
        .select("id, full_name")
        .eq("role", "tech")
        .order("full_name")
    : { data: [] as { id: string; full_name: string | null }[] };

  return (
    <section className="card" style={{ display: "grid", gap: 12 }}>
      <h1>Work Orders</h1>
      <form className="row" method="get">
        <select name="status" defaultValue={searchParams.status ?? ""}>
          <option value="">All status</option>
          <option value="new">new</option>
          <option value="assigned">assigned</option>
          <option value="in_progress">in_progress</option>
          <option value="completed">completed</option>
          <option value="closed">closed</option>
        </select>

        <select name="priority" defaultValue={searchParams.priority ?? ""}>
          <option value="">All priority</option>
          <option value="low">low</option>
          <option value="medium">medium</option>
          <option value="high">high</option>
          <option value="critical">critical</option>
        </select>

        <input
          name="property"
          defaultValue={searchParams.property ?? ""}
          placeholder="Property UUID"
        />

        {canFilterTechnician ? (
          <select name="technician" defaultValue={searchParams.technician ?? ""}>
            <option value="">All technicians</option>
            {techOptions?.map((tech) => (
              <option key={tech.id} value={tech.id}>
                {tech.full_name ?? tech.id}
              </option>
            ))}
          </select>
        ) : null}

        <button type="submit">Apply filters</button>
      </form>

      <table>
        <thead>
          <tr>
            <th>Title</th>
            <th>Status</th>
            <th>Priority</th>
            <th>Property</th>
            <th>Technician</th>
            <th>Updated</th>
          </tr>
        </thead>
        <tbody>
          {workOrders?.map((wo) => (
            <tr key={wo.id}>
              <td>
                <Link href={`/work-orders/${wo.id}`}>{wo.title}</Link>
              </td>
              <td>{wo.status}</td>
              <td>{wo.priority}</td>
              <td>{wo.property_id ?? "-"}</td>
              <td>{wo.technician_id}</td>
              <td>{new Date(wo.updated_at).toLocaleString()}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
