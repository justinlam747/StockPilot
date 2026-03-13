interface PageHeaderProps {
  title: string;
  children?: React.ReactNode;
}

/**
 * Standard page header with title and optional action area.
 *
 * Usage:
 *   <PageHeader title="Dashboard">
 *     <button className="grid-btn grid-btn--primary">Sync Now</button>
 *   </PageHeader>
 */
export default function PageHeader({ title, children }: PageHeaderProps) {
  return (
    <div className="bento-header">
      <h1 className="grid-page-title">{title}</h1>
      {children && <div className="bento-header-actions">{children}</div>}
    </div>
  );
}
