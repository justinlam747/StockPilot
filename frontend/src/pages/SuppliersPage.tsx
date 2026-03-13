import { useState, useEffect, useCallback } from "react";
import {
  DataTable,
  Modal,
  FormLayout,
  TextField,
} from "@shopify/polaris";
import {
  UserMultiple,
  Time,
  Delivery,
} from "@carbon/icons-react";
import { useAuthenticatedFetch } from "../hooks/useAuthenticatedFetch";
import {
  StatusBadge,
  PageHeader,
  PageLoading,
  CardHeader,
  EmptyState,
  KPISidebar,
  Toast,
} from "../components/ui";
import type { StatusTone } from "../components/ui";

interface Supplier {
  id: number;
  name: string;
  email: string;
  contact_name: string;
  lead_time_days: number;
  notes: string;
}

const emptySupplier = { name: "", email: "", contact_name: "", lead_time_days: 14, notes: "" };

function leadTimeTone(days: number): StatusTone {
  if (days <= 7) return "ok";
  if (days <= 14) return "warning";
  return "neutral";
}

export default function SuppliersPage() {
  const fetch = useAuthenticatedFetch();
  const [suppliers, setSuppliers] = useState<Supplier[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState(emptySupplier);
  const [toast, setToast] = useState<string | null>(null);

  const loadSuppliers = useCallback(async () => {
    setLoading(true);
    try {
      const result = await fetch("/suppliers");
      setSuppliers(result.suppliers);
    } finally {
      setLoading(false);
    }
  }, [fetch]);

  useEffect(() => {
    loadSuppliers();
  }, [loadSuppliers]);

  const openAddModal = () => {
    setEditingId(null);
    setForm(emptySupplier);
    setModalOpen(true);
  };

  const openEditModal = (supplier: Supplier) => {
    setEditingId(supplier.id);
    setForm({
      name: supplier.name,
      email: supplier.email || "",
      contact_name: supplier.contact_name || "",
      lead_time_days: supplier.lead_time_days || 14,
      notes: supplier.notes || "",
    });
    setModalOpen(true);
  };

  const handleSave = async () => {
    const body = { supplier: form };
    if (editingId) {
      await fetch(`/suppliers/${editingId}`, { method: "PATCH", body: JSON.stringify(body) });
    } else {
      await fetch("/suppliers", { method: "POST", body: JSON.stringify(body) });
    }
    setModalOpen(false);
    setToast(editingId ? "Supplier updated" : "Supplier added");
    await loadSuppliers();
  };

  const handleDelete = async (id: number) => {
    await fetch(`/suppliers/${id}`, { method: "DELETE" });
    setToast("Supplier deleted");
    await loadSuppliers();
  };

  if (loading) return <PageLoading title="Suppliers" />;

  const avgLeadTime = suppliers.length > 0
    ? Math.round(suppliers.reduce((sum, s) => sum + (s.lead_time_days || 0), 0) / suppliers.length)
    : 0;

  const fastest = suppliers.length > 0
    ? suppliers.reduce((a, b) => a.lead_time_days < b.lead_time_days ? a : b).name
    : "\u2014";

  const kpis = [
    { icon: UserMultiple, label: "Suppliers", value: String(suppliers.length) },
    { icon: Time, label: "Avg Lead Time", value: `${avgLeadTime}d` },
    { icon: Delivery, label: "Fastest", value: fastest },
  ];

  const rows = suppliers.map((s) => [
    s.name,
    <span className="mono-sm" key={s.id + "e"}>{s.email || "\u2014"}</span>,
    s.contact_name || "\u2014",
    <span className="lead-time" key={s.id + "lt"}>
      <StatusBadge tone={leadTimeTone(s.lead_time_days)}>{s.lead_time_days} days</StatusBadge>
    </span>,
    <div className="inline-actions" key={s.id}>
      <button className="grid-btn--plain" onClick={() => openEditModal(s)}>Edit</button>
      <button className="grid-btn--plain" style={{ color: "var(--color-destructive)" }} onClick={() => handleDelete(s.id)}>Delete</button>
    </div>,
  ]);

  return (
    <div className="bento-page">
      <PageHeader title="Suppliers">
        <button className="grid-btn grid-btn--primary" onClick={openAddModal}>
          + Add Supplier
        </button>
      </PageHeader>

      <div className="invg-layout">
        <div className="invg-main">
          <div className="grid-card">
            <CardHeader title="Supplier Directory" description="All vendors and their contact details" />
            {rows.length > 0 ? (
              <DataTable
                columnContentTypes={["text", "text", "text", "text", "text"]}
                headings={["Name", "Email", "Contact", "Lead Time", ""]}
                rows={rows}
              />
            ) : (
              <EmptyState message="No suppliers yet. Add your first supplier to get started." />
            )}
          </div>
        </div>

        <KPISidebar title="Overview" items={kpis} />
      </div>

      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title={editingId ? "Edit Supplier" : "Add Supplier"}
        primaryAction={{ content: "Save", onAction: handleSave }}
        secondaryActions={[{ content: "Cancel", onAction: () => setModalOpen(false) }]}
      >
        <Modal.Section>
          <FormLayout>
            <TextField label="Name" value={form.name} onChange={(v) => setForm({ ...form, name: v })} autoComplete="off" />
            <TextField label="Email" type="email" value={form.email} onChange={(v) => setForm({ ...form, email: v })} autoComplete="off" />
            <TextField label="Contact Name" value={form.contact_name} onChange={(v) => setForm({ ...form, contact_name: v })} autoComplete="off" />
            <TextField label="Lead Time (days)" type="number" value={String(form.lead_time_days)} onChange={(v) => setForm({ ...form, lead_time_days: parseInt(v, 10) || 0 })} autoComplete="off" />
            <TextField label="Notes" value={form.notes} onChange={(v) => setForm({ ...form, notes: v })} multiline={3} autoComplete="off" />
          </FormLayout>
        </Modal.Section>
      </Modal>

      {toast && <Toast message={toast} onDismiss={() => setToast(null)} />}
    </div>
  );
}
