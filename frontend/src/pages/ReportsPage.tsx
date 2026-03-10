import { useState, useEffect, useCallback } from "react";
import {
  Page,
  Card,
  Text,
  BlockStack,
  InlineStack,
  Button,
  DataTable,
  Spinner,
  Box,
} from "@shopify/polaris";
import { useAuthenticatedFetch } from "../hooks/useAuthenticatedFetch";

interface Report {
  id: number;
  week_start: string;
  created_at: string;
  emailed_at: string | null;
}

interface ReportDetail {
  id: number;
  week_start: string;
  payload: {
    top_sellers?: Array<{ sku: string; title: string; units_sold: number }>;
    stockouts?: Array<{ sku: string; title: string; triggered_at: string }>;
    low_sku_count?: number;
    reorder_suggestions?: Array<{
      supplier_name: string;
      items: Array<{ sku: string; suggested_qty: number }>;
    }>;
    ai_commentary?: string;
  };
}

export default function ReportsPage() {
  const fetch = useAuthenticatedFetch();
  const [reports, setReports] = useState<Report[]>([]);
  const [selectedReport, setSelectedReport] = useState<ReportDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [generating, setGenerating] = useState(false);

  const loadReports = useCallback(async () => {
    setLoading(true);
    try {
      const result = await fetch("/reports");
      setReports(result.reports);
    } finally {
      setLoading(false);
    }
  }, [fetch]);

  useEffect(() => {
    loadReports();
  }, [loadReports]);

  const handleViewReport = async (id: number) => {
    const result = await fetch(`/reports/${id}`);
    setSelectedReport(result);
  };

  const handleGenerate = async () => {
    setGenerating(true);
    try {
      await fetch("/reports/generate", { method: "POST" });
      await loadReports();
    } finally {
      setGenerating(false);
    }
  };

  if (loading) {
    return (
      <Page title="Reports">
        <Box padding="800">
          <InlineStack align="center"><Spinner size="large" /></InlineStack>
        </Box>
      </Page>
    );
  }

  if (selectedReport) {
    const payload = selectedReport.payload;
    const topSellerRows = (payload.top_sellers || []).map((s) => [
      s.sku,
      s.title,
      String(s.units_sold),
    ]);

    return (
      <Page
        title={`Report — ${new Date(selectedReport.week_start).toLocaleDateString()}`}
        backAction={{ content: "Reports", onAction: () => setSelectedReport(null) }}
      >
        <BlockStack gap="400">
          {topSellerRows.length > 0 && (
            <Card>
              <BlockStack gap="200">
                <Text as="h2" variant="headingMd">Top Sellers</Text>
                <DataTable
                  columnContentTypes={["text", "text", "numeric"]}
                  headings={["SKU", "Product", "Units Sold"]}
                  rows={topSellerRows}
                />
              </BlockStack>
            </Card>
          )}
          <Card>
            <BlockStack gap="200">
              <Text as="h2" variant="headingMd">Summary</Text>
              <Text as="p" variant="bodyMd">
                Stockout events: {payload.stockouts?.length ?? 0}
              </Text>
              <Text as="p" variant="bodyMd">
                Low stock SKUs: {payload.low_sku_count ?? 0}
              </Text>
            </BlockStack>
          </Card>
          {payload.ai_commentary && (
            <Card>
              <BlockStack gap="200">
                <Text as="h2" variant="headingMd">AI Insights</Text>
                <Text as="p" variant="bodyMd">{payload.ai_commentary}</Text>
              </BlockStack>
            </Card>
          )}
        </BlockStack>
      </Page>
    );
  }

  const rows = reports.map((r) => [
    new Date(r.week_start).toLocaleDateString(),
    new Date(r.created_at).toLocaleDateString(),
    r.emailed_at ? "Yes" : "No",
    <Button variant="plain" onClick={() => handleViewReport(r.id)} key={r.id}>
      View
    </Button>,
  ]);

  return (
    <Page title="Reports">
      <Card>
        <BlockStack gap="400">
          <InlineStack align="space-between">
            <Text as="h2" variant="headingMd">Weekly Reports</Text>
            <Button variant="tertiary" loading={generating} onClick={handleGenerate}>
              Generate Report
            </Button>
          </InlineStack>
          {rows.length > 0 ? (
            <DataTable
              columnContentTypes={["text", "text", "text", "text"]}
              headings={["Week", "Created", "Emailed", ""]}
              rows={rows}
            />
          ) : (
            <Text as="p" variant="bodyMd" tone="subdued">
              No reports yet.
            </Text>
          )}
        </BlockStack>
      </Card>
    </Page>
  );
}
