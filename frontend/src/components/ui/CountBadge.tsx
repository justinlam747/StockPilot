interface CountBadgeProps {
  count: number;
  label: string;
  zeroText?: string;
}

/**
 * Compact count badge for card headers.
 *
 * Usage:
 *   <CountBadge count={8} label="alerts" zeroText="All clear" />
 */
export default function CountBadge({ count, label, zeroText }: CountBadgeProps) {
  if (count === 0 && zeroText) {
    return <span className="count-badge">{zeroText}</span>;
  }
  return (
    <span className="count-badge">
      {count} {label}{count !== 1 && !label.endsWith("s") ? "s" : ""}
    </span>
  );
}
