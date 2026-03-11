import { useState, useEffect, useCallback } from "react";
import {
  Page,
  Layout,
  DataTable,
  InlineStack,
} from "@shopify/polaris";
import { useAuthenticatedFetch } from "../hooks/useAuthenticatedFetch";
import { PageSpinner, StatCard, CardSection, EmptyState, StatusBadge } from "../components";

interface LowStockItem {
  id: number;
  sku: string;
  title: string;
  available: number;
  threshold: number;
}

interface DashboardData {
  total_skus: number;
  low_stock_count: number;
  out_of_stock_count: number;
  synced_at: string | null;
  low_stock_items: LowStockItem[];
}

export default function DashboardPage() {
  const fetch = useAuthenticatedFetch();
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);

  const loadData = useCallback(async () => {
    try {
      const result = await fetch("/shop");
      setData(result);
    } finally {
      setLoading(false);
    }
  }, [fetch]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handleSync = async () => {
    setSyncing(true);
    try {
      await fetch("/inventory/sync", { method: "POST" });
    } finally {
      setSyncing(false);
    }
  };

  if (loading) {
    return <PageSpinner title="Dashboard" />;
  }

  const rows = (data?.low_stock_items || []).map((item) => [
    item.sku,
    item.title,
    String(item.available),
    String(item.threshold),
    <StatusBadge key={item.id} status={item.available <= 0 ? "out_of_stock" : "low_stock"} />,
  ]);

  return (
    <Page title="Dashboard">
      <Layout>
        <Layout.Section>
          <InlineStack gap="400" wrap>
            <StatCard label="Total SKUs" value={data?.total_skus ?? 0} />
            <StatCard label="Low Stock" value={data?.low_stock_count ?? 0} />
            <StatCard label="Out of Stock" value={data?.out_of_stock_count ?? 0} />
            <StatCard
              label="Last Sync"
              value={data?.synced_at ? new Date(data.synced_at).toLocaleString() : "Never"}
            />
          </InlineStack>
        </Layout.Section>

        <Layout.Section>
          <CardSection
            title="Low Stock Items"
            action={{ content: "Sync Now", onAction: handleSync, loading: syncing }}
          >
            {rows.length > 0 ? (
              <DataTable
                columnContentTypes={["text", "text", "numeric", "numeric", "text"]}
                headings={["SKU", "Product", "Available", "Threshold", "Status"]}
                rows={rows}
              />
            ) : (
              <EmptyState message="No low-stock items detected." />
            )}
          </CardSection>
        </Layout.Section>
      </Layout>
    </Page>
  );
}
