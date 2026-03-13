interface EmptyStateProps {
  message: string;
}

/**
 * Empty data state shown when a table or list has no rows.
 *
 * Usage:
 *   <EmptyState message="No suppliers yet. Add your first supplier to get started." />
 */
export default function EmptyState({ message }: EmptyStateProps) {
  return (
    <div className="grid-empty">
      <div className="grid-empty-text">{message}</div>
    </div>
  );
}
