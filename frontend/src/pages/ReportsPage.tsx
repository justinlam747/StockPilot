import { useState, useEffect, useCallback } from "react";
import { DataTable } from "@shopify/polaris";
import {
  Analytics,
  Report,
  Email,
  WarningAlt,
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

interface ReportItem {
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
  const [reports, setReports] = useState<ReportItem[]>([]);
  const [selectedReport, setSelectedReport] = useState<ReportDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [generating, setGenerating] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

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
      setToast("Report generated successfully");
      await loadReports();
    } finally {
      setGenerating(false);
    }
  };

  if (loading) return <PageLoading title="Reports" />;

  const emailedCount = reports.filter(r => r.emailed_at).length;
  const pendingCount = reports.filter(r => !r.emailed_at).length;

  const kpis = [
    { icon: Report, label: "Total Reports", value: String(reports.length) },
    { icon: Email, label: "Emailed", value: String(emailedCount) },
    { icon: WarningAlt, label: "Pending", value: String(pendingCount) },
  ];

  // Detail view
  if (selectedReport) {
    const payload = selectedReport.payload;
    const topSellerRows = (payload.top_sellers || []).map((s) => [
      <span className="mono-sm" key={s.sku}>{s.sku}</span>,
      s.title,
      <span className="mono-sm" key={s.sku + "u"}>{s.units_sold}</span>,
    ]);

    const detailKpis = [
      { icon: Analytics, label: "Top Sellers", value: String(topSellerRows.length) },
      { icon: WarningAlt, label: "Stockouts", value: String(payload.stockouts?.length ?? 0) },
      { icon: Report, label: "Low SKUs", value: String(payload.low_sku_count ?? 0) },
    ];

    return (
      <div className="bento-page">
        <div className="bento-header">
          <div>
            <button className="grid-btn--back" onClick={() => setSelectedReport(null)}>
              &larr; Back to Reports
            </button>
            <h1 className="grid-page-title" style={{ marginTop: 8 }}>
              Week of {new Date(selectedReport.week_start).toLocaleDateString()}
            </h1>
          </div>
        </div>

        <div className="invg-layout">
          <div className="invg-main">
            {topSellerRows.length > 0 && (
              <div className="grid-card">
                <CardHeader title="Top Sellers" description="Highest unit sales this week" />
                <DataTable columnContentTypes={["text", "text", "numeric"]} headings={["SKU", "Product", "Units Sold"]} rows={topSellerRows} />
              </div>
            )}
            {payload.ai_commentary && (
              <div className="grid-card">
                <div className="grid-card-header">
                  <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                    <span className="ai-badge">AI</span>
                    <div className="grid-card-title">Insights</div>
                  </div>
                </div>
                <div style={{ fontSize: 14, color: "var(--color-text)", lineHeight: 1.7 }}>
                  {payload.ai_commentary}
                </div>
              </div>
            )}
          </div>

          <KPISidebar title="Summary" items={detailKpis} />
        </div>
      </div>
    );
  }

  // List view
  const rows = reports.map((r) => [
    <span className="mono-sm" key={r.id + "w"}>{new Date(r.week_start).toLocaleDateString()}</span>,
    <span className="mono-sm" key={r.id + "c"}>{new Date(r.created_at).toLocaleDateString()}</span>,
    r.emailed_at
      ? <StatusBadge tone="ok" key={r.id + "e"}>Sent</StatusBadge>
      : <StatusBadge tone="neutral" key={r.id + "e"}>Pending</StatusBadge>,
    <button className="grid-btn--plain" onClick={() => handleViewReport(r.id)} key={r.id}>View</button>,
  ]);

  return (
    <div className="bento-page">
      <PageHeader title="Reports">
        <button className="grid-btn grid-btn--primary" disabled={generating} onClick={handleGenerate}>
          {generating ? "Generating..." : "Generate Report"}
        </button>
      </PageHeader>

      <div className="invg-layout">
        <div className="invg-main">
          <div className="grid-card">
            <CardHeader title="Weekly Reports" description='Click "View" for the full breakdown with AI insights' />
            {rows.length > 0 ? (
              <DataTable columnContentTypes={["text", "text", "text", "text"]} headings={["Week", "Created", "Status", ""]} rows={rows} />
            ) : (
              <EmptyState message="No reports yet. Generate your first one above." />
            )}
          </div>
        </div>

        <KPISidebar title="Overview" items={kpis} />
      </div>

      {toast && <Toast message={toast} onDismiss={() => setToast(null)} />}
    </div>
  );
}
