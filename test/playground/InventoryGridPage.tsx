/**
 * Product inventory grid — KPI sidebar, tall cards, density toggle, gallery/detail views.
 */
import { useState } from "react";
import { TextField } from "@shopify/polaris";
import {
  Image as ImageIcon,
  List as ListIcon,
  Catalog,
  Box,
  WarningAlt,
  Currency,
} from "@carbon/icons-react";

interface InventoryProduct {
  id: number;
  title: string;
  category: string;
  sku: string;
  image: string;
  available: number;
  threshold: number;
  price: number;
  status: "active" | "low" | "out";
}

const PRODUCTS: InventoryProduct[] = [
  { id: 1, title: "Classic Black Tee", category: "Men's T-Shirts", sku: "BLK-TEE-M", image: "https://placehold.co/600x800/1A1A1A/FFFFFF?text=Black+Tee", available: 48, threshold: 10, price: 29.99, status: "active" },
  { id: 2, title: "White Pullover Hoodie", category: "Men's Hoodies", sku: "WHT-HOODIE-L", image: "https://placehold.co/600x800/F6F6F7/6D7175?text=White+Hoodie", available: 2, threshold: 15, price: 79.99, status: "low" },
  { id: 3, title: "Denim Trucker Jacket", category: "Men's Jackets", sku: "DNM-JKT-S", image: "https://placehold.co/600x800/4A6FA5/FFFFFF?text=Denim+Jacket", available: 0, threshold: 5, price: 120.00, status: "out" },
  { id: 4, title: "Grey Slim Jogger", category: "Men's Pants", sku: "GRY-JOGGER-XL", image: "https://placehold.co/600x800/8C9196/FFFFFF?text=Grey+Jogger", available: 3, threshold: 8, price: 64.99, status: "low" },
  { id: 5, title: "Navy Baseball Cap", category: "Accessories", sku: "NVY-CAP-OS", image: "https://placehold.co/600x800/2C3E6B/FFFFFF?text=Navy+Cap", available: 0, threshold: 20, price: 24.99, status: "out" },
  { id: 6, title: "Red Crew Socks", category: "Accessories", sku: "RED-SOCK-M", image: "https://placehold.co/600x800/D72C0D/FFFFFF?text=Red+Socks", available: 6, threshold: 25, price: 12.99, status: "low" },
  { id: 7, title: "Olive Cargo Pant", category: "Men's Pants", sku: "OLV-CARGO-32", image: "https://placehold.co/600x800/6B7C3E/FFFFFF?text=Olive+Cargo", available: 1, threshold: 10, price: 74.99, status: "low" },
  { id: 8, title: "Beige Canvas Tote", category: "Bags", sku: "BEG-TOTE-OS", image: "https://placehold.co/600x800/C9BAAB/6D7175?text=Canvas+Tote", available: 0, threshold: 12, price: 39.99, status: "out" },
  { id: 9, title: "Air Max Runner", category: "Men's Shoes", sku: "AIR-MAX-10", image: "https://placehold.co/600x800/1A1A1A/C9CCCF?text=Air+Max", available: 22, threshold: 10, price: 189.99, status: "active" },
  { id: 10, title: "White Low-Top Sneaker", category: "Men's Shoes", sku: "WHT-SNKR-9", image: "https://placehold.co/600x800/EDEEEF/6D7175?text=White+Sneaker", available: 35, threshold: 10, price: 149.99, status: "active" },
  { id: 11, title: "Merino Wool Beanie", category: "Accessories", sku: "MRN-BNE-OS", image: "https://placehold.co/600x800/3D3D3D/FFFFFF?text=Beanie", available: 67, threshold: 15, price: 34.99, status: "active" },
  { id: 12, title: "Performance Shorts", category: "Men's Shorts", sku: "PRF-SHRT-L", image: "https://placehold.co/600x800/6D7175/FFFFFF?text=Shorts", available: 41, threshold: 10, price: 44.99, status: "active" },
];

const FILTERS = [
  { key: "All", label: "All", count: PRODUCTS.length },
  { key: "Low Stock", label: "Low Stock", count: PRODUCTS.filter(p => p.status === "low").length },
  { key: "Out of Stock", label: "Out of Stock", count: PRODUCTS.filter(p => p.status === "out").length },
];

const DENSITY_OPTIONS = [
  { cols: 4, label: "4" },
  { cols: 3, label: "3" },
  { cols: 2, label: "2" },
] as const;

type ViewMode = "detail" | "gallery";

function StockBar({ available, threshold }: { available: number; threshold: number }) {
  const max = Math.max(threshold * 2, 1);
  const pct = Math.min(100, (available / max) * 100);
  const barColor = available === 0 ? "var(--color-stroke)" : "var(--color-text-disabled)";
  return (
    <div className="invg-stock-bar-track">
      <div className="invg-stock-bar-fill" style={{ width: `${pct}%`, background: barColor }} />
    </div>
  );
}

function DetailCard({ product, qty, onUpdateQty }: {
  product: InventoryProduct;
  qty: number;
  onUpdateQty: (id: number, qty: number) => void;
}) {
  const isOut = qty === 0;
  const isLow = qty > 0 && qty <= product.threshold;
  const statusLabel = isOut ? "Out of Stock" : isLow ? "Low Stock" : "In Stock";
  const dotClass = isOut ? "status-dot--critical" : isLow ? "status-dot--warning" : "status-dot--ok";

  return (
    <div className="invg-card">
      <div className="invg-card-img invg-card-img--tall">
        <img src={product.image} alt={product.title} style={{ opacity: isOut ? 0.4 : 1 }} />
        <span className="invg-card-badge">
          <span className={`status-dot ${dotClass}`} />
          {statusLabel}
        </span>
      </div>
      <div className="invg-card-body">
        <div className="invg-card-header">
          <span className="invg-card-title">{product.title}</span>
          <span className="invg-card-category">{product.category}</span>
        </div>
        <div className="invg-card-meta">
          <span className="mono-xs">{product.sku}</span>
          <span className="invg-card-price">${product.price.toFixed(2)}</span>
          <StockBar available={qty} threshold={product.threshold} />
          <span className="invg-card-qty">{qty} units</span>
        </div>
        <div className="invg-card-actions">
          <div className="invg-stepper">
            <button className="invg-stepper-btn" onClick={() => onUpdateQty(product.id, Math.max(0, qty - 1))}>−</button>
            <span className="invg-stepper-value">{qty}</span>
            <button className="invg-stepper-btn" onClick={() => onUpdateQty(product.id, qty + 1)}>+</button>
          </div>
          <span className="invg-card-line-value">
            ${(qty * product.price).toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 0 })}
          </span>
        </div>
      </div>
    </div>
  );
}

function GalleryCard({ product, qty }: {
  product: InventoryProduct;
  qty: number;
}) {
  const isOut = qty === 0;
  return (
    <div className="invg-gallery-card">
      <div className="invg-gallery-img invg-gallery-img--tall">
        <img src={product.image} alt={product.title} style={{ opacity: isOut ? 0.4 : 1 }} />
      </div>
      <div className="invg-gallery-info">
        <span className="invg-gallery-name">{product.title}</span>
        <span className="invg-gallery-stock">{qty} in stock</span>
      </div>
    </div>
  );
}

export default function InventoryGridPage() {
  const [filter, setFilter] = useState("All");
  const [quantities, setQuantities] = useState<Record<number, number>>(
    () => Object.fromEntries(PRODUCTS.map(p => [p.id, p.available]))
  );
  const [search, setSearch] = useState("");
  const [cols, setCols] = useState(3);
  const [view, setView] = useState<ViewMode>("detail");

  const filtered = PRODUCTS.filter(p => {
    if (filter === "Low Stock") return p.status === "low";
    if (filter === "Out of Stock") return p.status === "out";
    return true;
  }).filter(p =>
    search === "" ||
    p.title.toLowerCase().includes(search.toLowerCase()) ||
    p.sku.toLowerCase().includes(search.toLowerCase())
  );

  const totalValue = filtered.reduce((sum, p) => sum + p.price * (quantities[p.id] ?? p.available), 0);
  const totalUnits = filtered.reduce((sum, p) => sum + (quantities[p.id] ?? p.available), 0);
  const needsAttention = PRODUCTS.filter(p => p.status === "low").length + PRODUCTS.filter(p => p.status === "out").length;

  const updateQty = (id: number, qty: number) => {
    setQuantities(prev => ({ ...prev, [id]: qty }));
  };

  const kpis = [
    { icon: Catalog, label: "Products", value: String(PRODUCTS.length) },
    { icon: Box, label: "Total Units", value: totalUnits.toLocaleString() },
    { icon: WarningAlt, label: "Attention", value: String(needsAttention) },
    { icon: Currency, label: "Value", value: `$${totalValue.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 0 })}` },
  ];

  return (
    <div className="bento-page">
      {/* Header */}
      <div className="bento-header">
        <h1 className="grid-page-title">Product Inventory</h1>
        <div className="bento-header-actions">
          <span className="bento-sync-status">
            {filtered.length} of {PRODUCTS.length} products
          </span>
          <div className="inv-density">
            <button
              className={`inv-density-btn${view === "detail" ? " inv-density-btn--active" : ""}`}
              onClick={() => setView("detail")}
              title="Detail view"
              aria-label="Detail view"
            >
              <ListIcon size={16} />
            </button>
            <button
              className={`inv-density-btn${view === "gallery" ? " inv-density-btn--active" : ""}`}
              onClick={() => setView("gallery")}
              title="Gallery view"
              aria-label="Gallery view"
            >
              <ImageIcon size={16} />
            </button>
          </div>
          <div className="inv-density">
            {DENSITY_OPTIONS.map((opt) => (
              <button
                key={opt.cols}
                className={`inv-density-btn${cols === opt.cols ? " inv-density-btn--active" : ""}`}
                onClick={() => setCols(opt.cols)}
                title={`${opt.cols} per row`}
                aria-label={`${opt.cols} per row`}
              >
                <span className="invg-density-label">{opt.label}</span>
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Main layout: grid + KPI sidebar */}
      <div className="invg-layout">
        {/* Left: toolbar + product grid */}
        <div className="invg-main">
          {/* Toolbar */}
          <div className="invg-toolbar">
            <div className="invg-filters">
              {FILTERS.map(f => (
                <button
                  key={f.key}
                  className={`invg-filter-btn${filter === f.key ? " invg-filter-btn--active" : ""}`}
                  onClick={() => setFilter(f.key)}
                >
                  {f.label}
                  <span className="invg-filter-count">{f.count}</span>
                </button>
              ))}
            </div>
            <div style={{ width: 220 }}>
              <TextField
                label=""
                labelHidden
                value={search}
                onChange={setSearch}
                placeholder="Search…"
                autoComplete="off"
                clearButton
                onClearButtonClick={() => setSearch("")}
              />
            </div>
          </div>

          {/* Product grid */}
          <div
            className="inv-grid"
            style={{ gridTemplateColumns: `repeat(${cols}, 1fr)` }}
          >
            {filtered.map(product =>
              view === "gallery" ? (
                <GalleryCard
                  key={product.id}
                  product={product}
                  qty={quantities[product.id] ?? product.available}
                />
              ) : (
                <DetailCard
                  key={product.id}
                  product={product}
                  qty={quantities[product.id] ?? product.available}
                  onUpdateQty={updateQty}
                />
              )
            )}
          </div>

          {filtered.length === 0 && (
            <div className="grid-empty" style={{ marginTop: 8 }}>
              <div className="grid-empty-text">No products match your filters.</div>
              <button className="grid-btn" style={{ marginTop: 12 }} onClick={() => setFilter("All")}>
                Show all products
              </button>
            </div>
          )}
        </div>

        {/* Right: KPI sidebar */}
        <aside className="invg-kpi-sidebar">
          <div className="invg-kpi-sidebar-title">Overview</div>
          {kpis.map((kpi) => {
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
      </div>
    </div>
  );
}
