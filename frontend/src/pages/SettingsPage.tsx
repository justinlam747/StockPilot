import { useState, useEffect, useCallback } from "react";
import {
  InlineStack,
  FormLayout,
  TextField,
  Select,
  DataTable,
} from "@shopify/polaris";
import {
  Settings as SettingsIcon,
  Email,
  Time,
  Api,
} from "@carbon/icons-react";
import { useAuthenticatedFetch } from "../hooks/useAuthenticatedFetch";
import {
  StatusBadge,
  PageHeader,
  PageLoading,
  CardHeader,
  KPISidebar,
  Toast,
} from "../components/ui";

interface WebhookEndpoint {
  id: number;
  url: string;
  event_type: string;
  is_active: boolean;
}

const TIMEZONE_OPTIONS = [
  { label: "Eastern (America/Toronto)", value: "America/Toronto" },
  { label: "Central (America/Chicago)", value: "America/Chicago" },
  { label: "Mountain (America/Denver)", value: "America/Denver" },
  { label: "Pacific (America/Los_Angeles)", value: "America/Los_Angeles" },
  { label: "UTC", value: "UTC" },
];

const DAY_OPTIONS = [
  { label: "Monday", value: "monday" },
  { label: "Tuesday", value: "tuesday" },
  { label: "Wednesday", value: "wednesday" },
  { label: "Thursday", value: "thursday" },
  { label: "Friday", value: "friday" },
  { label: "Saturday", value: "saturday" },
  { label: "Sunday", value: "sunday" },
];

export default function SettingsPage() {
  const fetch = useAuthenticatedFetch();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

  const [alertEmail, setAlertEmail] = useState("");
  const [threshold, setThreshold] = useState("10");
  const [timezone, setTimezone] = useState("America/Toronto");
  const [reportDay, setReportDay] = useState("monday");

  const [endpoints, setEndpoints] = useState<WebhookEndpoint[]>([]);
  const [newUrl, setNewUrl] = useState("");
  const [newEventType, setNewEventType] = useState("low_stock");

  const loadSettings = useCallback(async () => {
    setLoading(true);
    try {
      const [settings, webhooksResult] = await Promise.all([
        fetch("/settings"),
        fetch("/webhook_endpoints"),
      ]);
      setAlertEmail(settings.alert_email || "");
      setThreshold(String(settings.low_stock_threshold));
      setTimezone(settings.timezone);
      setReportDay(settings.weekly_report_day);
      setEndpoints(webhooksResult.webhook_endpoints);
    } finally {
      setLoading(false);
    }
  }, [fetch]);

  useEffect(() => {
    loadSettings();
  }, [loadSettings]);

  const handleSave = async () => {
    setSaving(true);
    try {
      await fetch("/settings", {
        method: "PATCH",
        body: JSON.stringify({
          settings: {
            alert_email: alertEmail,
            low_stock_threshold: parseInt(threshold, 10),
            timezone,
            weekly_report_day: reportDay,
          },
        }),
      });
      setToast("Settings saved successfully");
    } finally {
      setSaving(false);
    }
  };

  const handleAddEndpoint = async () => {
    if (!newUrl) return;
    await fetch("/webhook_endpoints", {
      method: "POST",
      body: JSON.stringify({
        webhook_endpoint: { url: newUrl, event_type: newEventType, is_active: true },
      }),
    });
    setNewUrl("");
    setToast("Webhook endpoint added");
    await loadSettings();
  };

  const handleDeleteEndpoint = async (id: number) => {
    await fetch(`/webhook_endpoints/${id}`, { method: "DELETE" });
    setToast("Webhook endpoint removed");
    await loadSettings();
  };

  if (loading) return <PageLoading title="Settings" />;

  const kpis = [
    { icon: Email, label: "Alert Email", value: alertEmail || "Not set" },
    { icon: SettingsIcon, label: "Threshold", value: `${threshold} units` },
    { icon: Time, label: "Timezone", value: timezone.split("/").pop() || "UTC" },
    { icon: Api, label: "Webhooks", value: String(endpoints.length) },
  ];

  const endpointRows = endpoints.map((ep) => [
    <span className="mono-sm" key={ep.id + "u"}>{ep.url}</span>,
    <StatusBadge tone={ep.event_type === "low_stock" ? "warning" : "critical"} key={ep.id + "t"}>
      {ep.event_type.replace("_", " ").toUpperCase()}
    </StatusBadge>,
    ep.is_active
      ? <StatusBadge tone="ok" key={ep.id + "s"}>Active</StatusBadge>
      : <StatusBadge tone="neutral" key={ep.id + "s"}>Inactive</StatusBadge>,
    <button className="grid-btn--plain" style={{ color: "var(--color-destructive)" }} key={ep.id} onClick={() => handleDeleteEndpoint(ep.id)}>Delete</button>,
  ]);

  return (
    <div className="bento-page">
      <PageHeader title="Settings">
        <button className="grid-btn grid-btn--primary" onClick={handleSave} disabled={saving}>
          {saving ? "Saving..." : "Save Settings"}
        </button>
      </PageHeader>

      {toast && <Toast message={toast} onDismiss={() => setToast(null)} />}

      <div className="invg-layout">
        <div className="invg-main">
          {/* Alert & Report Settings */}
          <div className="grid-card">
            <CardHeader title="Alert & Report Settings" description="Configure notifications, thresholds, and report schedule" />
            <FormLayout>
              <TextField
                label="Alert Email"
                type="email"
                value={alertEmail}
                onChange={setAlertEmail}
                autoComplete="off"
                helpText="Receives low-stock and out-of-stock alerts"
              />
              <TextField
                label="Low Stock Threshold"
                type="number"
                value={threshold}
                onChange={setThreshold}
                autoComplete="off"
                helpText="Products below this count trigger an alert"
              />
              <Select label="Timezone" options={TIMEZONE_OPTIONS} value={timezone} onChange={setTimezone} />
              <Select label="Weekly Report Day" options={DAY_OPTIONS} value={reportDay} onChange={setReportDay} />
            </FormLayout>
          </div>

          {/* Webhooks */}
          <div className="grid-card">
            <CardHeader title="Webhook Endpoints" description="Real-time notifications for stock events" />
            {endpointRows.length > 0 && (
              <div style={{ marginBottom: 16 }}>
                <DataTable
                  columnContentTypes={["text", "text", "text", "text"]}
                  headings={["Endpoint URL", "Event", "Status", ""]}
                  rows={endpointRows}
                />
              </div>
            )}
            <div className="grid-form-area">
              <div className="grid-form-label">Add New Endpoint</div>
              <InlineStack gap="300" blockAlign="end">
                <div style={{ flex: 1 }}>
                  <TextField label="URL" value={newUrl} onChange={setNewUrl} autoComplete="off" placeholder="https://hooks.slack.com/..." />
                </div>
                <Select
                  label="Event Type"
                  options={[
                    { label: "Low Stock", value: "low_stock" },
                    { label: "Out of Stock", value: "out_of_stock" },
                  ]}
                  value={newEventType}
                  onChange={setNewEventType}
                />
                <button className="grid-btn grid-btn--primary" onClick={handleAddEndpoint}>
                  + Add
                </button>
              </InlineStack>
            </div>
          </div>
        </div>

        <KPISidebar title="Current Config" items={kpis} />
      </div>
    </div>
  );
}
