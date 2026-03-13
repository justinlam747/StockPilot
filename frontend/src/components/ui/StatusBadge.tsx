export type StatusTone = "ok" | "warning" | "critical" | "neutral" | "info";

interface StatusBadgeProps {
  tone: StatusTone;
  children: React.ReactNode;
}

/**
 * Semantic status indicator with colored dot + label.
 *
 * Usage:
 *   <StatusBadge tone="warning">Low Stock</StatusBadge>
 *   <StatusBadge tone="critical">Out of Stock</StatusBadge>
 */
export default function StatusBadge({ tone, children }: StatusBadgeProps) {
  return (
    <span className={`status-indicator status-indicator--${tone}`}>
      <span className={`status-dot status-dot--${tone}`} />
      {children}
    </span>
  );
}
