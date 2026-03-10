import { useState, useEffect, useCallback } from "react";
import {
  Page,
  Layout,
  Card,
  Text,
  BlockStack,
  InlineStack,
  Badge,
  DataTable,
  Button,
  Spinner,
  Box,
} from "@shopify/polaris";
import { useAuthenticatedFetch } from "../hooks/useAuthenticatedFetch";

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
    return (
      <Page title="Dashboard">
        <Box padding="800">
          <InlineStack align="center">
            <Spinner size="large" />
          </InlineStack>
        </Box>
      </Page>
    );
  }

  const statusBadge = (item: LowStockItem) => {
    if (item.available <= 0) {
      return <Badge tone="critical">Out of Stock</Badge>;
    }
    return <Badge tone="warning">Low Stock</Badge>;
  };

  const rows = (data?.low_stock_items || []).map((item) => [
    item.sku,
    item.title,
    String(item.available),
    String(item.threshold),
    statusBadge(item),
  ]);

  return (
    <Page title="Dashboard">
      <Layout>
        <Layout.Section>
          <InlineStack gap="400" wrap>
            <Box minWidth="200px">
              <Card>
                <BlockStack gap="200">
                  <Text as="p" variant="bodySm" tone="subdued">Total SKUs</Text>
                  <Text as="p" variant="headingLg">{data?.total_skus ?? 0}</Text>
                </BlockStack>
              </Card>
            </Box>
            <Box minWidth="200px">
              <Card>
                <BlockStack gap="200">
                  <Text as="p" variant="bodySm" tone="subdued">Low Stock</Text>
                  <Text as="p" variant="headingLg">{data?.low_stock_count ?? 0}</Text>
                </BlockStack>
              </Card>
            </Box>
            <Box minWidth="200px">
              <Card>
                <BlockStack gap="200">
                  <Text as="p" variant="bodySm" tone="subdued">Out of Stock</Text>
                  <Text as="p" variant="headingLg">{data?.out_of_stock_count ?? 0}</Text>
                </BlockStack>
              </Card>
            </Box>
            <Box minWidth="200px">
              <Card>
                <BlockStack gap="200">
                  <Text as="p" variant="bodySm" tone="subdued">Last Sync</Text>
                  <Text as="p" variant="headingLg">
                    {data?.synced_at
                      ? new Date(data.synced_at).toLocaleString()
                      : "Never"}
                  </Text>
                </BlockStack>
              </Card>
            </Box>
          </InlineStack>
        </Layout.Section>

        <Layout.Section>
          <Card>
            <BlockStack gap="400">
              <InlineStack align="space-between">
                <Text as="h2" variant="headingMd">Low Stock Items</Text>
                <Button
                  variant="tertiary"
                  loading={syncing}
                  onClick={handleSync}
                >
                  Sync Now
                </Button>
              </InlineStack>
              {rows.length > 0 ? (
                <DataTable
                  columnContentTypes={["text", "text", "numeric", "numeric", "text"]}
                  headings={["SKU", "Product", "Available", "Threshold", "Status"]}
                  rows={rows}
                />
              ) : (
                <Text as="p" variant="bodyMd" tone="subdued">
                  No low-stock items detected.
                </Text>
              )}
            </BlockStack>
          </Card>
        </Layout.Section>
      </Layout>
    </Page>
  );
}
