import { Badge } from "@shopify/polaris";
import type { BadgeProps } from "@shopify/polaris";

interface StatusConfig {
  label: string;
  tone?: BadgeProps["tone"];
}

const STATUS_MAP: Record<string, StatusConfig> = {
  out_of_stock: { label: "Out of Stock", tone: "critical" },
  low_stock: { label: "Low Stock", tone: "warning" },
  active: { label: "Active", tone: "success" },
  inactive: { label: "Inactive" },
  sent: { label: "Sent", tone: "success" },
  draft: { label: "Draft" },
};

interface StatusBadgeProps {
  status: string;
}

export default function StatusBadge({ status }: StatusBadgeProps) {
  const config = STATUS_MAP[status];
  if (config) {
    return <Badge tone={config.tone}>{config.label}</Badge>;
  }
  return <Badge tone="info">{status}</Badge>;
}
