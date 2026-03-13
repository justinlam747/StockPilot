export interface KPIItem {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  icon: React.ComponentType<any>;
  label: string;
  value: string;
}

interface KPISidebarProps {
  title: string;
  items: KPIItem[];
}

/**
 * Sticky sidebar with KPI summary items. Used in two-column layouts.
 *
 * Usage:
 *   <KPISidebar title="Overview" items={[
 *     { icon: UserMultiple, label: "Suppliers", value: "12" },
 *     { icon: Time, label: "Avg Lead Time", value: "14d" },
 *   ]} />
 */
export default function KPISidebar({ title, items }: KPISidebarProps) {
  return (
    <aside className="invg-kpi-sidebar">
      <div className="invg-kpi-sidebar-title">{title}</div>
      {items.map((kpi) => {
        const Icon = kpi.icon;
        return (
          <div className="invg-kpi-item" key={kpi.label}>
            <span className="invg-kpi-icon"><Icon size={18} /></span>
            <div className="invg-kpi-text">
              <span className="invg-kpi-label">{kpi.label}</span>
              <span className="invg-kpi-value">{kpi.value}</span>
            </div>
          </div>
        );
      })}
    </aside>
  );
}
