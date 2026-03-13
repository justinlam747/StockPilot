interface CardHeaderProps {
  title: string;
  description?: string;
  children?: React.ReactNode;
}

/**
 * Standard card header with title, optional description, and optional trailing content (badge, action).
 *
 * Usage:
 *   <CardHeader title="Low Stock Items" description="Products below their reorder threshold">
 *     <CountBadge count={8} label="alerts" />
 *   </CardHeader>
 */
export default function CardHeader({ title, description, children }: CardHeaderProps) {
  return (
    <div className="grid-card-header">
      <div>
        <div className="grid-card-title">{title}</div>
        {description && <div className="grid-card-desc">{description}</div>}
      </div>
      {children}
    </div>
  );
}
