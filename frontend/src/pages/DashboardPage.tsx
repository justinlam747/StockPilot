import { useState, useEffect, useCallback } from "react";
import { DataTable } from "@shopify/polaris";
import {
  Catalog,
  Box,
  WarningAlt,
  Currency,
} from "@carbon/icons-react";
import { useAuthenticatedFetch } from "../hooks/useAuthenticatedFetch";
import {
  StatusBadge,
  PageHeader,
  PageLoading,
  CardHeader,
  EmptyState,
  CountBadge,
  Toast,
} from "../components/ui";

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
  const [toast, setToast] = useState<string | null>(null);

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
      setToast("Inventory synced successfully");
    } finally {
      setSyncing(false);
    }
  };

  if (loading) return <PageLoading title="Dashboard" />;

  const needsAttention = (data?.low_stock_count ?? 0) + (data?.out_of_stock_count ?? 0);

  const rows = (data?.low_stock_items || []).map((item) => [
    <span className="mono-sm" key={item.id + "s"}>{item.sku}</span>,
    item.title,
    <span className="mono-sm" key={item.id + "a"}>{item.available}</span>,
    <span className="mono-sm" key={item.id + "t"}>{item.threshold}</span>,
    item.available <= 0
      ? <StatusBadge tone="critical" key={item.id}>Out of Stock</StatusBadge>
      : <StatusBadge tone="warning" key={item.id}>Low Stock</StatusBadge>,
  ]);

  const syncLabel = data?.synced_at
    ? `Synced ${new Date(data.synced_at).toLocaleString()}`
    : "Never synced";

  const kpis = [
    { icon: Catalog, label: "Total Products", value: String(data?.total_skus ?? 0) },
    { icon: Box, label: "Total Units", value: "---" },
    { icon: WarningAlt, label: "Needs Attention", value: String(needsAttention) },
    { icon: Currency, label: "Inventory Value", value: "$---" },
  ];

  return (
    <div className="bento-page">
      <PageHeader title="Dashboard">
        <span className="bento-sync-status">{syncLabel}</span>
        <button
          className="grid-btn grid-btn--primary"
          disabled={syncing}
          onClick={handleSync}
        >
          {syncing ? "Syncing\u2026" : "Sync Now"}
        </button>
      </PageHeader>

      <div className="bento-layout">
        {/* Left: tall KPI list card */}
        <div className="bento-card bento-kpi-list">
          {kpis.map((kpi) => {
            const Icon = kpi.icon;
            return (
              <div className="bento-kpi-row" key={kpi.label}>
                <span className="bento-kpi-icon">
                  <Icon size={20} />
                </span>
                <div className="bento-kpi-content">
                  <div className="stat-label">{kpi.label}</div>
                  <div className="stat-value">{kpi.value}</div>
                </div>
              </div>
            );
          })}
        </div>

        {/* Right: 2x2 metric grid */}
        <div className="bento-metrics">
          <div className="bento-card bento-metric-card">
            <div className="stat-label">Low Stock</div>
            <div className="stat-value">{data?.low_stock_count ?? 0}</div>
            <div className="stat-desc">Below reorder threshold</div>
          </div>
          <div className="bento-card bento-metric-card">
            <div className="stat-label">Out of Stock</div>
            <div className="stat-value">{data?.out_of_stock_count ?? 0}</div>
            <div className="stat-desc">Zero units available</div>
          </div>
          <div className="bento-card bento-metric-card">
            <div className="stat-label">Healthy Stock</div>
            <div className="stat-value">
              {(data?.total_skus ?? 0) - (data?.low_stock_count ?? 0) - (data?.out_of_stock_count ?? 0)}
            </div>
            <div className="stat-desc">Above threshold</div>
          </div>
          <div className="bento-card bento-metric-card">
            <div className="stat-label">Sync Status</div>
            <div className="stat-value mono-sm" style={{ fontSize: 14, marginTop: 4 }}>
              {data?.synced_at ? new Date(data.synced_at).toLocaleDateString() : "Never"}
            </div>
            <div className="stat-desc">Last inventory sync</div>
          </div>
        </div>
      </div>

      {/* Full-width low stock table */}
      <div className="bento-card" style={{ marginTop: 10 }}>
        <CardHeader title="Low Stock Items" description={`Products below their reorder threshold \u2014 ${rows.length} items`}>
          <CountBadge count={rows.length} label="alerts" zeroText="All clear" />
        </CardHeader>
        {rows.length > 0 ? (
          <DataTable
            columnContentTypes={["text", "text", "numeric", "numeric", "text"]}
            headings={["SKU", "Product", "Available", "Threshold", "Status"]}
            rows={rows}
          />
        ) : (
          <EmptyState message="All products are above their reorder thresholds." />
        )}
      </div>

      {toast && <Toast message={toast} onDismiss={() => setToast(null)} />}
    </div>
  );
}
