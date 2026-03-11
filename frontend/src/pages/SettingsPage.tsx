import { useState, useEffect, useCallback } from "react";
import {
  Page,
  Card,
  Text,
  BlockStack,
  InlineStack,
  Button,
  FormLayout,
  TextField,
  Select,
  DataTable,
  Banner,
} from "@shopify/polaris";
import { useAuthenticatedFetch } from "../hooks/useAuthenticatedFetch";
import { PageSpinner } from "../components";

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
  const [saved, setSaved] = useState(false);

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
    setSaved(false);
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
      setSaved(true);
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
    await loadSettings();
  };

  const handleDeleteEndpoint = async (id: number) => {
    await fetch(`/webhook_endpoints/${id}`, { method: "DELETE" });
    await loadSettings();
  };

  if (loading) {
    return <PageSpinner title="Settings" />;
  }

  const endpointRows = endpoints.map((ep) => [
    ep.url,
    ep.event_type,
    ep.is_active ? "Active" : "Inactive",
    <Button variant="plain" tone="critical" key={ep.id} onClick={() => handleDeleteEndpoint(ep.id)}>
      Delete
    </Button>,
  ]);

  return (
    <Page title="Settings">
      <BlockStack gap="400">
        {saved && <Banner tone="success" onDismiss={() => setSaved(false)}>Settings saved.</Banner>}

        <Card>
          <BlockStack gap="300">
            <Text as="h2" variant="headingMd">Alert Settings</Text>
            <FormLayout>
              <TextField
                label="Alert Email"
                type="email"
                value={alertEmail}
                onChange={setAlertEmail}
                autoComplete="off"
              />
              <TextField
                label="Low Stock Threshold"
                type="number"
                value={threshold}
                onChange={setThreshold}
                autoComplete="off"
              />
              <Select
                label="Timezone"
                options={TIMEZONE_OPTIONS}
                value={timezone}
                onChange={setTimezone}
              />
              <Select
                label="Weekly Report Day"
                options={DAY_OPTIONS}
                value={reportDay}
                onChange={setReportDay}
              />
            </FormLayout>
            <InlineStack align="end">
              <Button variant="tertiary" loading={saving} onClick={handleSave}>
                Save
              </Button>
            </InlineStack>
          </BlockStack>
        </Card>

        <Card>
          <BlockStack gap="300">
            <Text as="h2" variant="headingMd">Webhook Endpoints</Text>
            {endpointRows.length > 0 && (
              <DataTable
                columnContentTypes={["text", "text", "text", "text"]}
                headings={["URL", "Event", "Status", ""]}
                rows={endpointRows}
              />
            )}
            <InlineStack gap="300" blockAlign="end">
              <TextField
                label="URL"
                value={newUrl}
                onChange={setNewUrl}
                autoComplete="off"
              />
              <Select
                label="Event Type"
                options={[
                  { label: "Low Stock", value: "low_stock" },
                  { label: "Out of Stock", value: "out_of_stock" },
                ]}
                value={newEventType}
                onChange={setNewEventType}
              />
              <Button variant="tertiary" onClick={handleAddEndpoint}>Add</Button>
            </InlineStack>
          </BlockStack>
        </Card>
      </BlockStack>
    </Page>
  );
}
