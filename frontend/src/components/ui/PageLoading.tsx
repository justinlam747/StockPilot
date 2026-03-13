import { Spinner } from "@shopify/polaris";

interface PageLoadingProps {
  title: string;
}

/**
 * Full-page loading state with title and centered spinner.
 *
 * Usage:
 *   if (loading) return <PageLoading title="Dashboard" />;
 */
export default function PageLoading({ title }: PageLoadingProps) {
  return (
    <div className="bento-page">
      <div className="bento-header">
        <h1 className="grid-page-title">{title}</h1>
      </div>
      <div className="grid-loading">
        <Spinner size="large" />
      </div>
    </div>
  );
}
