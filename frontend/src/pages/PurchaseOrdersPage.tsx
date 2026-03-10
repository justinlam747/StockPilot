import { useState, useEffect, useCallback } from "react";
import {
  Page,
  Card,
  Text,
  BlockStack,
  InlineStack,
  Button,
  DataTable,
  Select,
  TextField,
  Spinner,
  Box,
  Badge,
} from "@shopify/polaris";
import { useAuthenticatedFetch } from "../hooks/useAuthenticatedFetch";

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
      await loadData();
    } finally {
      setGenerating(false);
    }
  };

  const handleSendEmail = async () => {
    if (!activePO) return;
    await fetch(`/purchase_orders/${activePO.id}/send_email`, { method: "POST" });
    setActivePO(null);
    await loadData();
  };

  if (loading) {
    return (
      <Page title="Purchase Orders">
        <Box padding="800">
          <InlineStack align="center"><Spinner size="large" /></InlineStack>
        </Box>
      </Page>
    );
  }

  const supplierOptions = suppliers.map((s) => ({
    label: s.name,
    value: String(s.id),
  }));

  const statusBadge = (status: string) => {
    switch (status) {
      case "sent":
        return <Badge tone="success">Sent</Badge>;
      case "draft":
        return <Badge>Draft</Badge>;
      default:
        return <Badge tone="info">{status}</Badge>;
    }
  };

  const rows = purchaseOrders.map((po) => [
    `#${po.id}`,
    po.supplier.name,
    po.order_date,
    po.expected_delivery || "—",
    statusBadge(po.status),
    <Button variant="plain" key={po.id} onClick={() => { setActivePO(po); setDraftBody(po.draft_body || ""); }}>
      View
    </Button>,
  ]);

  return (
    <Page title="Purchase Orders">
      <BlockStack gap="400">
        <Card>
          <BlockStack gap="300">
            <Text as="h2" variant="headingMd">Generate Draft PO</Text>
            <InlineStack gap="300" blockAlign="end">
              {supplierOptions.length > 0 && (
                <Select
                  label="Supplier"
                  options={supplierOptions}
                  value={selectedSupplier}
                  onChange={setSelectedSupplier}
                />
              )}
              <Button variant="tertiary" loading={generating} onClick={handleGenerateDraft}>
                Generate Draft
              </Button>
            </InlineStack>
          </BlockStack>
        </Card>

        {activePO && (
          <Card>
            <BlockStack gap="300">
              <Text as="h2" variant="headingMd">PO #{activePO.id} — {activePO.supplier.name}</Text>
              <DataTable
                columnContentTypes={["text", "text", "numeric", "numeric"]}
                headings={["SKU", "Product", "Qty", "Unit Price"]}
                rows={activePO.line_items.map((li) => [
                  li.sku,
                  li.variant?.product?.title || li.variant?.title || "—",
                  String(li.quantity_ordered),
                  `$${Number(li.unit_price).toFixed(2)}`,
                ])}
              />
              <TextField
                label="Draft Email"
                value={draftBody}
                onChange={setDraftBody}
                multiline={8}
                autoComplete="off"
              />
              <InlineStack align="end">
                <Button variant="tertiary" onClick={handleSendEmail}>
                  Send to Supplier
                </Button>
              </InlineStack>
            </BlockStack>
          </Card>
        )}

        <Card>
          <BlockStack gap="300">
            <Text as="h2" variant="headingMd">Past Orders</Text>
            {rows.length > 0 ? (
              <DataTable
                columnContentTypes={["text", "text", "text", "text", "text", "text"]}
                headings={["ID", "Supplier", "Date", "Expected", "Status", ""]}
                rows={rows}
              />
            ) : (
              <Text as="p" variant="bodyMd" tone="subdued">No purchase orders yet.</Text>
            )}
          </BlockStack>
        </Card>
      </BlockStack>
    </Page>
  );
}
