import { useState, useEffect, useCallback } from "react";
import {
  InlineStack,
  DataTable,
  Select,
  TextField,
} from "@shopify/polaris";
import {
  DocumentAdd,
  SendAlt,
  Document,
  Box,
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

interface Supplier {
  id: number;
  name: string;
}

interface LineItem {
  id: number;
  sku: string;
  quantity_ordered: number;
  unit_price: number;
  variant?: { title: string; product?: { title: string } };
}

interface PurchaseOrder {
  id: number;
  status: string;
  order_date: string;
  expected_delivery: string;
  draft_body: string | null;
  supplier: Supplier;
  line_items: LineItem[];
}

export default function PurchaseOrdersPage() {
  const fetch = useAuthenticatedFetch();
  const [purchaseOrders, setPurchaseOrders] = useState<PurchaseOrder[]>([]);
  const [suppliers, setSuppliers] = useState<Supplier[]>([]);
  const [selectedSupplier, setSelectedSupplier] = useState("");
  const [loading, setLoading] = useState(true);
  const [generating, setGenerating] = useState(false);
  const [activePO, setActivePO] = useState<PurchaseOrder | null>(null);
  const [draftBody, setDraftBody] = useState("");
  const [toast, setToast] = useState<string | null>(null);

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [posResult, suppliersResult] = await Promise.all([
        fetch("/purchase_orders"),
        fetch("/suppliers"),
      ]);
      setPurchaseOrders(posResult.purchase_orders);
      setSuppliers(suppliersResult.suppliers);
      if (suppliersResult.suppliers.length > 0) {
        setSelectedSupplier(String(suppliersResult.suppliers[0].id));
      }
    } finally {
      setLoading(false);
    }
  }, [fetch]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handleGenerateDraft = async () => {
    if (!selectedSupplier) return;
    setGenerating(true);
    try {
      const result = await fetch("/purchase_orders/generate_draft", {
        method: "POST",
        body: JSON.stringify({ supplier_id: parseInt(selectedSupplier, 10) }),
      });
      setActivePO(result);
      setDraftBody(result.draft_body || "");
      setToast("Draft PO generated successfully");
      await loadData();
    } finally {
      setGenerating(false);
    }
  };

  const handleSendEmail = async () => {
    if (!activePO) return;
    await fetch(`/purchase_orders/${activePO.id}/send_email`, { method: "POST" });
    setActivePO(null);
    setToast("Purchase order sent to supplier");
    await loadData();
  };

  if (loading) return <PageLoading title="Purchase Orders" />;

  const supplierOptions = suppliers.map((s) => ({ label: s.name, value: String(s.id) }));
  const sentCount = purchaseOrders.filter(po => po.status === "sent").length;
  const draftCount = purchaseOrders.filter(po => po.status === "draft").length;
  const totalItems = purchaseOrders.reduce((sum, po) => sum + po.line_items.reduce((s, li) => s + li.quantity_ordered, 0), 0);

  const kpis = [
    { icon: DocumentAdd, label: "Total Orders", value: String(purchaseOrders.length) },
    { icon: SendAlt, label: "Sent", value: String(sentCount) },
    { icon: Document, label: "Drafts", value: String(draftCount) },
    { icon: Box, label: "Total Units", value: String(totalItems) },
  ];

  const rows = purchaseOrders.map((po) => [
    <span className="mono-sm" key={po.id + "id"}>#{po.id}</span>,
    po.supplier.name,
    <span className="mono-sm" key={po.id + "d"}>{po.order_date}</span>,
    <span className="mono-sm" key={po.id + "e"}>{po.expected_delivery || "\u2014"}</span>,
    <StatusBadge tone={po.status === "sent" ? "ok" : "warning"} key={po.id + "s"}>
      {po.status.toUpperCase()}
    </StatusBadge>,
    <button className="grid-btn--plain" key={po.id} onClick={() => { setActivePO(po); setDraftBody(po.draft_body || ""); }}>View</button>,
  ]);

  return (
    <div className="bento-page">
      <PageHeader title="Purchase Orders">
        <span className="ai-badge">AI</span>
      </PageHeader>

      <div className="invg-layout">
        <div className="invg-main">
          {/* Generate section */}
          <div className="grid-card">
            <CardHeader title="Generate Draft PO" description="Select a supplier \u2014 Claude drafts the order from low-stock items" />
            <InlineStack gap="300" blockAlign="end">
              {supplierOptions.length > 0 && (
                <Select label="Supplier" options={supplierOptions} value={selectedSupplier} onChange={setSelectedSupplier} />
              )}
              <button className="grid-btn grid-btn--primary" onClick={handleGenerateDraft} disabled={generating}>
                {generating ? "Generating..." : "Generate Draft"}
              </button>
            </InlineStack>
          </div>

          {/* Active PO detail */}
          {activePO && (
            <div className="grid-card">
              <CardHeader
                title={`PO #${activePO.id} \u2014 ${activePO.supplier.name}`}
                description="Review line items and edit the draft email before sending"
              />
              <DataTable
                columnContentTypes={["text", "text", "numeric", "numeric"]}
                headings={["SKU", "Product", "Qty", "Unit Price"]}
                rows={activePO.line_items.map((li) => [
                  <span className="mono-sm" key={li.id + "s"}>{li.sku}</span>,
                  li.variant?.product?.title || li.variant?.title || "\u2014",
                  <span className="mono-sm" key={li.id + "q"}>{li.quantity_ordered}</span>,
                  <span className="mono-sm" key={li.id + "p"}>${Number(li.unit_price).toFixed(2)}</span>,
                ])}
              />
              <div style={{ marginTop: 16 }}>
                <TextField label="Draft Email" value={draftBody} onChange={setDraftBody} multiline={8} autoComplete="off" />
              </div>
              <div style={{ display: "flex", justifyContent: "flex-end", marginTop: 12 }}>
                <button className="grid-btn grid-btn--primary" onClick={handleSendEmail}>Send to Supplier</button>
              </div>
            </div>
          )}

          {/* Order history */}
          <div className="grid-card">
            <CardHeader title="Order History" description='All purchase orders \u2014 click "View" for details' />
            {rows.length > 0 ? (
              <DataTable
                columnContentTypes={["text", "text", "text", "text", "text", "text"]}
                headings={["ID", "Supplier", "Date", "Expected", "Status", ""]}
                rows={rows}
              />
            ) : (
              <EmptyState message="No purchase orders yet. Generate your first draft above." />
            )}
          </div>
        </div>

        <KPISidebar title="Overview" items={kpis} />
      </div>

      {toast && <Toast message={toast} onDismiss={() => setToast(null)} />}
    </div>
  );
}
