import { useState, useEffect, useCallback } from "react";
import {
  Tabs,
  Pagination,
  Spinner,
  InlineStack,
} from "@shopify/polaris";
import {
  Grid as Grid4Icon,
  Row as Row3Icon,
  Column as Row2Icon,
} from "@carbon/icons-react";
import { useAuthenticatedFetch } from "../hooks/useAuthenticatedFetch";
import { StatusBadge } from "../components";

interface Variant {
  id: number;
  sku: string;
  title: string;
}

interface Product {
  id: number;
  title: string;
  status: string;
  variants: Variant[];
}

interface Meta {
  current_page: number;
  total_pages: number;
  total_count: number;
  per_page: number;
}

const DENSITY_OPTIONS = [
  { cols: 4, icon: Grid4Icon, label: "4 per row" },
  { cols: 3, icon: Row3Icon, label: "3 per row" },
  { cols: 2, icon: Row2Icon, label: "2 per row" },
] as const;

function ProductCard({ product }: { product: Product }) {
  const isActive = product.status === "active";
  const firstSku = product.variants[0]?.sku;
  return (
    <div className="inv-card">
      <div className="inv-card-row">
        <span className={`inv-card-dot ${isActive ? "status-dot--ok" : "status-dot--neutral"}`} />
        <div className="inv-card-info">
          <span className="inv-card-title">{product.title}</span>
          <span className="inv-card-meta">
            {firstSku && <span className="mono-xs">{firstSku}</span>}
            <span>{product.variants.length} variant{product.variants.length !== 1 ? "s" : ""}</span>
          </span>
        </div>
      </div>
    </div>
  );
}

export default function InventoryPage() {
  const fetch = useAuthenticatedFetch();
  const [products, setProducts] = useState<Product[]>([]);
  const [meta, setMeta] = useState<Meta>({ current_page: 1, total_pages: 1, total_count: 0, per_page: 25 });
  const [loading, setLoading] = useState(true);
  const [selectedTab, setSelectedTab] = useState(0);
  const [cols, setCols] = useState(3);

  const filters = ["", "low_stock", "out_of_stock"];
  const tabs = [
    { id: "all", content: "All" },
    { id: "low_stock", content: "Low Stock" },
    { id: "out_of_stock", content: "Out of Stock" },
  ];

  const loadProducts = useCallback(
    async (page = 1) => {
      setLoading(true);
      try {
        const filter = filters[selectedTab];
        const query = filter
          ? `/products?page=${page}&filter=${filter}`
          : `/products?page=${page}`;
        const result = await fetch(query);
        setProducts(result.products);
        setMeta(result.meta);
      } finally {
        setLoading(false);
      }
    },
    [fetch, selectedTab]
  );

  useEffect(() => {
    loadProducts(1);
  }, [loadProducts]);

  return (
    <div className="bento-page">
      {/* Header row: title left, density + count right */}
      <div className="bento-header">
        <h1 className="grid-page-title">Inventory</h1>
        <div className="bento-header-actions">
          <span className="bento-sync-status">{meta.total_count} products</span>
          <div className="inv-density">
            {DENSITY_OPTIONS.map((opt) => {
              const Icon = opt.icon;
              return (
                <button
                  key={opt.cols}
                  className={`inv-density-btn${cols === opt.cols ? " inv-density-btn--active" : ""}`}
                  onClick={() => setCols(opt.cols)}
                  title={opt.label}
                  aria-label={opt.label}
                >
                  <Icon size={16} />
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="inv-tabs">
        <Tabs tabs={tabs} selected={selectedTab} onSelect={setSelectedTab} />
      </div>

      {/* Card grid */}
      {loading ? (
        <div className="grid-loading">
          <Spinner size="large" />
        </div>
      ) : (
        <>
          <div
            className="inv-grid"
            style={{ gridTemplateColumns: `repeat(${cols}, 1fr)` }}
          >
            {products.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>

          {products.length === 0 && (
            <div className="grid-empty">
              <div className="grid-empty-text">No products match this filter.</div>
            </div>
          )}

          <div className="inv-pagination">
            <InlineStack align="center">
              <Pagination
                hasPrevious={meta.current_page > 1}
                hasNext={meta.current_page < meta.total_pages}
                onPrevious={() => loadProducts(meta.current_page - 1)}
                onNext={() => loadProducts(meta.current_page + 1)}
              />
            </InlineStack>
            <span className="bento-sync-status">
              Page {meta.current_page} of {meta.total_pages}
            </span>
          </div>
        </>
      )}
    </div>
  );
}
