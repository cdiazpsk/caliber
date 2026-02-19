import { revalidatePath } from "next/cache";
import { notFound } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase";

export default async function WorkOrderDetailPage({ params }: { params: { id: string } }) {
  const supabase = await createSupabaseServerClient();

  const { data: workOrder } = await supabase
    .from("work_orders")
    .select("id,title,description,status,priority,technician_id,updated_at")
    .eq("id", params.id)
    .maybeSingle();

  if (!workOrder) {
    notFound();
  }

  async function updateWorkOrder(formData: FormData) {
    "use server";

    const serverSupabase = await createSupabaseServerClient();
    const status = String(formData.get("status") || workOrder.status);
    const notes = String(formData.get("notes") || "");

    await serverSupabase
      .from("work_orders")
      .update({ status, description: notes })
      .eq("id", params.id);

    revalidatePath(`/work-orders/${params.id}`);
    revalidatePath("/work-orders");
  }

  async function uploadAttachment(formData: FormData) {
    "use server";

    const file = formData.get("photo");
    if (!(file instanceof File) || file.size === 0) return;

    const ext = file.name.includes(".") ? file.name.split(".").pop() : "jpg";
    const objectPath = `${params.id}/${crypto.randomUUID()}.${ext}`;

    const serverSupabase = await createSupabaseServerClient();
    const {
      data: { user },
    } = await serverSupabase.auth.getUser();

    if (!user) return;

    const { error: rowError } = await serverSupabase.from("work_order_attachments").insert({
      work_order_id: params.id,
      storage_path: objectPath,
      created_by: user.id,
    });

    if (rowError) return;

    const { error: uploadError } = await serverSupabase.storage
      .from("workorders")
      .upload(objectPath, file, { contentType: file.type || "image/jpeg", upsert: false });

    if (uploadError) {
      await serverSupabase.from("work_order_attachments").delete().eq("storage_path", objectPath);
      return;
    }

    revalidatePath(`/work-orders/${params.id}`);
  }

  const { data: attachments } = await supabase
    .from("work_order_attachments")
    .select("id,storage_path,created_at")
    .eq("work_order_id", params.id)
    .order("created_at", { ascending: false });

  const gallery = await Promise.all(
    (attachments ?? []).map(async (attachment) => {
      const { data } = await supabase.storage.from("workorders").createSignedUrl(attachment.storage_path, 3600);
      return {
        id: attachment.id,
        storagePath: attachment.storage_path,
        signedUrl: data?.signedUrl ?? null,
      };
    }),
  );

  return (
    <section className="card" style={{ display: "grid", gap: 12 }}>
      <h1>{workOrder.title}</h1>
      <p>
        <strong>ID:</strong> {workOrder.id}
      </p>
      <p>
        <strong>Technician:</strong> {workOrder.technician_id}
      </p>
      <p>
        <strong>Priority:</strong> {workOrder.priority}
      </p>
      <p>
        <strong>Last updated:</strong> {new Date(workOrder.updated_at).toLocaleString()}
      </p>

      <form action={updateWorkOrder} style={{ display: "grid", gap: 8 }}>
        <label>
          Status
          <select name="status" defaultValue={workOrder.status}>
            <option value="new">new</option>
            <option value="assigned">assigned</option>
            <option value="in_progress">in_progress</option>
            <option value="completed">completed</option>
            <option value="closed">closed</option>
          </select>
        </label>

        <label>
          Notes
          <textarea name="notes" defaultValue={workOrder.description ?? ""} rows={8} />
        </label>

        <button type="submit">Save</button>
      </form>

      <section style={{ display: "grid", gap: 8 }}>
        <h2>Photos</h2>
        <form action={uploadAttachment} className="row">
          <input type="file" name="photo" accept="image/*" required />
          <button type="submit">Upload photo</button>
        </form>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(180px, 1fr))", gap: 8 }}>
          {gallery.map((item) =>
            item.signedUrl ? (
              <a key={item.id} href={item.signedUrl} target="_blank" rel="noreferrer" className="card">
                <img src={item.signedUrl} alt={item.storagePath} style={{ width: "100%", borderRadius: 6 }} />
              </a>
            ) : null,
          )}
        </div>
      </section>
    </section>
  );
}
