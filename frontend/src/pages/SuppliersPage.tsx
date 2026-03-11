import { useState, useEffect, useCallback } from "react";
import {
  Page,
  DataTable,
  Modal,
  FormLayout,
  TextField,
  Button,
  InlineStack,
} from "@shopify/polaris";
import { useAuthenticatedFetch } from "../hooks/useAuthenticatedFetch";
import { PageSpinner, CardSection, EmptyState } from "../components";

interface Supplier {
  id: number;
  name: string;
  email: string;
  contact_name: string;
  lead_time_days: number;
  notes: string;
}

const emptySupplier = { name: "", email: "", contact_name: "", lead_time_days: 14, notes: "" };

export default function SuppliersPage() {
  const fetch = useAuthenticatedFetch();
  const [suppliers, setSuppliers] = useState<Supplier[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState(emptySupplier);

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
    await loadSuppliers();
  };

  const handleDelete = async (id: number) => {
    if (confirm("Delete this supplier?")) {
      await fetch(`/suppliers/${id}`, { method: "DELETE" });
      await loadSuppliers();
    }
  };

  if (loading) {
    return <PageSpinner title="Suppliers" />;
  }

  const rows = suppliers.map((s) => [
    s.name,
    s.email || "—",
    s.contact_name || "—",
    String(s.lead_time_days ?? "—"),
    <InlineStack gap="200" key={s.id}>
      <Button variant="plain" onClick={() => openEditModal(s)}>Edit</Button>
      <Button variant="plain" tone="critical" onClick={() => handleDelete(s.id)}>Delete</Button>
    </InlineStack>,
  ]);

  return (
    <Page title="Suppliers">
      <CardSection title="Suppliers" action={{ content: "Add Supplier", onAction: openAddModal }}>
        {rows.length > 0 ? (
          <DataTable
            columnContentTypes={["text", "text", "text", "numeric", "text"]}
            headings={["Name", "Email", "Contact", "Lead Time (days)", ""]}
            rows={rows}
          />
        ) : (
          <EmptyState message="No suppliers yet." />
        )}
      </CardSection>

      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title={editingId ? "Edit Supplier" : "Add Supplier"}
        primaryAction={{ content: "Save", onAction: handleSave }}
        secondaryActions={[{ content: "Cancel", onAction: () => setModalOpen(false) }]}
      >
        <Modal.Section>
          <FormLayout>
            <TextField
              label="Name"
              value={form.name}
              onChange={(v) => setForm({ ...form, name: v })}
              autoComplete="off"
            />
            <TextField
              label="Email"
              type="email"
              value={form.email}
              onChange={(v) => setForm({ ...form, email: v })}
              autoComplete="off"
            />
            <TextField
              label="Contact Name"
              value={form.contact_name}
              onChange={(v) => setForm({ ...form, contact_name: v })}
              autoComplete="off"
            />
            <TextField
              label="Lead Time (days)"
              type="number"
              value={String(form.lead_time_days)}
              onChange={(v) => setForm({ ...form, lead_time_days: parseInt(v, 10) || 0 })}
              autoComplete="off"
            />
            <TextField
              label="Notes"
              value={form.notes}
              onChange={(v) => setForm({ ...form, notes: v })}
              multiline={3}
              autoComplete="off"
            />
          </FormLayout>
        </Modal.Section>
      </Modal>
    </Page>
  );
}
