/**
 * Mock implementation of useAuthenticatedFetch for the playground.
 * Returns realistic sample data for every API endpoint the pages call.
 */
import { useCallback } from "react";

/* ═══════════════════════════════════════════════════
   Mock Data — comprehensive, realistic inventory
   ═══════════════════════════════════════════════════ */

const SUPPLIERS = [
  { id: 1, name: "Pacific Textile Co.", email: "orders@pacifictextile.com", contact_name: "Sarah Chen", lead_time_days: 14, notes: "Preferred vendor for cotton basics. Minimum order $500." },
  { id: 2, name: "Urban Stitch MFG", email: "wholesale@urbanstitch.co", contact_name: "Marcus Johnson", lead_time_days: 21, notes: "Premium denim and outerwear. Requires PO 30 days in advance." },
  { id: 3, name: "QuickShip Accessories", email: "b2b@quickshipacc.com", contact_name: "Li Wei", lead_time_days: 7, notes: "Hats, socks, bags — fastest turnaround in the network." },
  { id: 4, name: "Nordic Knit Works", email: "supply@nordicknit.se", contact_name: "Astrid Lindberg", lead_time_days: 28, notes: "Merino wool and cashmere. Seasonal availability — order early for winter." },
  { id: 5, name: "SoleTech Industries", email: "wholesale@soletech.com", contact_name: "David Park", lead_time_days: 18, notes: "Footwear specialist. Custom colorways require 45-day lead time." },
  { id: 6, name: "GreenThread Organic", email: "orders@greenthread.eco", contact_name: "Priya Sharma", lead_time_days: 25, notes: "GOTS-certified organic cotton. Eco-friendly packaging included." },
];

const LOW_STOCK_ITEMS = [
  { id: 1, sku: "BLK-TEE-M", title: "Classic Black Tee — Medium", available: 4, threshold: 10 },
  { id: 2, sku: "WHT-HOODIE-L", title: "White Pullover Hoodie — Large", available: 2, threshold: 15 },
  { id: 3, sku: "DNM-JKT-S", title: "Denim Trucker Jacket — Small", available: 0, threshold: 5 },
  { id: 4, sku: "GRY-JOGGER-XL", title: "Grey Slim Jogger — XL", available: 3, threshold: 8 },
  { id: 5, sku: "NVY-CAP-OS", title: "Navy Baseball Cap — One Size", available: 0, threshold: 20 },
  { id: 6, sku: "RED-SOCK-M", title: "Red Crew Socks — Medium", available: 6, threshold: 25 },
  { id: 7, sku: "OLV-CARGO-32", title: "Olive Cargo Pant — 32", available: 1, threshold: 10 },
  { id: 8, sku: "BEG-TOTE-OS", title: "Beige Canvas Tote — One Size", available: 0, threshold: 12 },
  { id: 9, sku: "MRN-BNE-OS", title: "Merino Wool Beanie — One Size", available: 5, threshold: 15 },
  { id: 10, sku: "PRF-SHRT-S", title: "Performance Shorts — Small", available: 3, threshold: 10 },
  { id: 11, sku: "CSH-SCRV-OS", title: "Cashmere Scarf — One Size", available: 0, threshold: 8 },
];

const PRODUCTS_PAGE_1 = [
  { id: 1, title: "Classic Black Tee", status: "active", variants: [
    { id: 10, sku: "BLK-TEE-S", title: "Small" },
    { id: 11, sku: "BLK-TEE-M", title: "Medium" },
    { id: 12, sku: "BLK-TEE-L", title: "Large" },
    { id: 13, sku: "BLK-TEE-XL", title: "XL" },
  ]},
  { id: 2, title: "White Pullover Hoodie", status: "active", variants: [
    { id: 20, sku: "WHT-HOODIE-S", title: "Small" },
    { id: 21, sku: "WHT-HOODIE-M", title: "Medium" },
    { id: 22, sku: "WHT-HOODIE-L", title: "Large" },
  ]},
  { id: 3, title: "Denim Trucker Jacket", status: "active", variants: [
    { id: 30, sku: "DNM-JKT-S", title: "Small" },
    { id: 31, sku: "DNM-JKT-M", title: "Medium" },
    { id: 32, sku: "DNM-JKT-L", title: "Large" },
  ]},
  { id: 4, title: "Grey Slim Jogger", status: "active", variants: [
    { id: 40, sku: "GRY-JOGGER-M", title: "Medium" },
    { id: 41, sku: "GRY-JOGGER-L", title: "Large" },
    { id: 42, sku: "GRY-JOGGER-XL", title: "XL" },
  ]},
  { id: 5, title: "Navy Baseball Cap", status: "active", variants: [
    { id: 50, sku: "NVY-CAP-OS", title: "One Size" },
  ]},
  { id: 6, title: "Red Crew Socks", status: "active", variants: [
    { id: 60, sku: "RED-SOCK-S", title: "Small" },
    { id: 61, sku: "RED-SOCK-M", title: "Medium" },
    { id: 62, sku: "RED-SOCK-L", title: "Large" },
  ]},
  { id: 7, title: "Olive Cargo Pant", status: "active", variants: [
    { id: 70, sku: "OLV-CARGO-30", title: "30" },
    { id: 71, sku: "OLV-CARGO-32", title: "32" },
    { id: 72, sku: "OLV-CARGO-34", title: "34" },
    { id: 73, sku: "OLV-CARGO-36", title: "36" },
  ]},
  { id: 8, title: "Beige Canvas Tote", status: "active", variants: [
    { id: 80, sku: "BEG-TOTE-OS", title: "One Size" },
  ]},
  { id: 9, title: "Air Max Runner", status: "active", variants: [
    { id: 90, sku: "AIR-MAX-8", title: "8" },
    { id: 91, sku: "AIR-MAX-9", title: "9" },
    { id: 92, sku: "AIR-MAX-10", title: "10" },
    { id: 93, sku: "AIR-MAX-11", title: "11" },
  ]},
  { id: 10, title: "White Low-Top Sneaker", status: "active", variants: [
    { id: 100, sku: "WHT-SNKR-8", title: "8" },
    { id: 101, sku: "WHT-SNKR-9", title: "9" },
    { id: 102, sku: "WHT-SNKR-10", title: "10" },
  ]},
];

const PRODUCTS_PAGE_2 = [
  { id: 11, title: "Merino Wool Beanie", status: "active", variants: [
    { id: 110, sku: "MRN-BNE-OS", title: "One Size" },
  ]},
  { id: 12, title: "Performance Shorts", status: "active", variants: [
    { id: 120, sku: "PRF-SHRT-S", title: "Small" },
    { id: 121, sku: "PRF-SHRT-M", title: "Medium" },
    { id: 122, sku: "PRF-SHRT-L", title: "Large" },
  ]},
  { id: 13, title: "Cashmere Scarf", status: "active", variants: [
    { id: 130, sku: "CSH-SCRV-OS", title: "One Size" },
  ]},
  { id: 14, title: "Linen Summer Shirt", status: "active", variants: [
    { id: 140, sku: "LNN-SHRT-S", title: "Small" },
    { id: 141, sku: "LNN-SHRT-M", title: "Medium" },
    { id: 142, sku: "LNN-SHRT-L", title: "Large" },
  ]},
  { id: 15, title: "Leather Belt", status: "active", variants: [
    { id: 150, sku: "LTH-BLT-S", title: "Small (28-30)" },
    { id: 151, sku: "LTH-BLT-M", title: "Medium (32-34)" },
    { id: 152, sku: "LTH-BLT-L", title: "Large (36-38)" },
  ]},
  { id: 16, title: "Organic Cotton Polo", status: "active", variants: [
    { id: 160, sku: "ORG-POLO-S", title: "Small" },
    { id: 161, sku: "ORG-POLO-M", title: "Medium" },
    { id: 162, sku: "ORG-POLO-L", title: "Large" },
    { id: 163, sku: "ORG-POLO-XL", title: "XL" },
  ]},
  { id: 17, title: "Slim Fit Chinos", status: "active", variants: [
    { id: 170, sku: "SLM-CHN-30", title: "30" },
    { id: 171, sku: "SLM-CHN-32", title: "32" },
    { id: 172, sku: "SLM-CHN-34", title: "34" },
  ]},
  { id: 18, title: "Wool Overcoat", status: "draft", variants: [
    { id: 180, sku: "WOL-OVR-M", title: "Medium" },
    { id: 181, sku: "WOL-OVR-L", title: "Large" },
  ]},
  { id: 19, title: "Graphic Print Tee", status: "active", variants: [
    { id: 190, sku: "GRX-TEE-S", title: "Small" },
    { id: 191, sku: "GRX-TEE-M", title: "Medium" },
    { id: 192, sku: "GRX-TEE-L", title: "Large" },
  ]},
  { id: 20, title: "Holiday Gift Set (2024)", status: "draft", variants: [
    { id: 200, sku: "GIFT-2024", title: "Default" },
  ]},
];

const PRODUCTS_PAGE_3 = [
  { id: 21, title: "Canvas Backpack", status: "active", variants: [
    { id: 210, sku: "CNV-BKP-OS", title: "One Size" },
  ]},
  { id: 22, title: "Corduroy Trucker Hat", status: "active", variants: [
    { id: 220, sku: "CRD-HAT-OS", title: "One Size" },
  ]},
  { id: 23, title: "French Terry Sweatshirt", status: "active", variants: [
    { id: 230, sku: "FRT-SWT-S", title: "Small" },
    { id: 231, sku: "FRT-SWT-M", title: "Medium" },
    { id: 232, sku: "FRT-SWT-L", title: "Large" },
  ]},
  { id: 24, title: "Rain Shell Jacket", status: "active", variants: [
    { id: 240, sku: "RN-SHL-M", title: "Medium" },
    { id: 241, sku: "RN-SHL-L", title: "Large" },
  ]},
  { id: 25, title: "Compression Socks 3-Pack", status: "active", variants: [
    { id: 250, sku: "CMP-SOK-SM", title: "S/M" },
    { id: 251, sku: "CMP-SOK-LX", title: "L/XL" },
  ]},
];

const PAGES: Record<number, typeof PRODUCTS_PAGE_1> = {
  1: PRODUCTS_PAGE_1,
  2: PRODUCTS_PAGE_2,
  3: PRODUCTS_PAGE_3,
};

const REPORTS = [
  { id: 1, week_start: "2026-03-03", created_at: "2026-03-03T09:00:00Z", emailed_at: "2026-03-03T09:05:00Z" },
  { id: 2, week_start: "2026-02-24", created_at: "2026-02-24T09:00:00Z", emailed_at: null },
  { id: 3, week_start: "2026-02-17", created_at: "2026-02-17T09:00:00Z", emailed_at: "2026-02-17T09:02:00Z" },
  { id: 4, week_start: "2026-02-10", created_at: "2026-02-10T09:00:00Z", emailed_at: "2026-02-10T09:08:00Z" },
  { id: 5, week_start: "2026-02-03", created_at: "2026-02-03T09:00:00Z", emailed_at: "2026-02-03T09:04:00Z" },
  { id: 6, week_start: "2026-01-27", created_at: "2026-01-27T09:00:00Z", emailed_at: null },
  { id: 7, week_start: "2026-01-20", created_at: "2026-01-20T09:00:00Z", emailed_at: "2026-01-20T09:12:00Z" },
];

const REPORT_DETAILS: Record<number, unknown> = {
  1: {
    id: 1,
    week_start: "2026-03-03",
    payload: {
      top_sellers: [
        { sku: "BLK-TEE-M", title: "Classic Black Tee — Medium", units_sold: 87 },
        { sku: "WHT-HOODIE-L", title: "White Pullover Hoodie — Large", units_sold: 54 },
        { sku: "GRY-JOGGER-M", title: "Grey Slim Jogger — Medium", units_sold: 41 },
        { sku: "AIR-MAX-10", title: "Air Max Runner — 10", units_sold: 38 },
        { sku: "PRF-SHRT-M", title: "Performance Shorts — Medium", units_sold: 29 },
      ],
      stockouts: [
        { sku: "DNM-JKT-S", title: "Denim Trucker Jacket — Small", triggered_at: "2026-03-05T16:30:00Z" },
        { sku: "NVY-CAP-OS", title: "Navy Baseball Cap — One Size", triggered_at: "2026-03-06T11:15:00Z" },
        { sku: "BEG-TOTE-OS", title: "Beige Canvas Tote — One Size", triggered_at: "2026-03-07T08:42:00Z" },
      ],
      low_sku_count: 11,
      reorder_suggestions: [
        { supplier_name: "Pacific Textile Co.", items: [
          { sku: "BLK-TEE-M", suggested_qty: 150 },
          { sku: "RED-SOCK-M", suggested_qty: 100 },
        ]},
        { supplier_name: "Urban Stitch MFG", items: [
          { sku: "DNM-JKT-S", suggested_qty: 50 },
          { sku: "OLV-CARGO-32", suggested_qty: 40 },
        ]},
      ],
      ai_commentary: "Black tees continue to dominate this week with 87 units sold for the medium alone — consider doubling your next reorder for medium sizes. The denim jacket stockout on March 5th likely cost 12–15 lost sales based on historical click-through rates. Three products hit zero stock this week, up from one last week — the trend suggests your current reorder thresholds may be too conservative for Q1 demand. Recommend setting up automated PO triggers for items that hit 50% of threshold, and increasing the Navy Cap threshold from 20 to 35 based on velocity.",
    },
  },
  2: {
    id: 2,
    week_start: "2026-02-24",
    payload: {
      top_sellers: [
        { sku: "BLK-TEE-M", title: "Classic Black Tee — Medium", units_sold: 72 },
        { sku: "WHT-SNKR-9", title: "White Low-Top Sneaker — 9", units_sold: 45 },
        { sku: "MRN-BNE-OS", title: "Merino Wool Beanie — One Size", units_sold: 33 },
      ],
      stockouts: [
        { sku: "CSH-SCRV-OS", title: "Cashmere Scarf — One Size", triggered_at: "2026-02-25T14:20:00Z" },
      ],
      low_sku_count: 8,
      ai_commentary: "Sneaker sales are surging as spring approaches — the White Low-Top is tracking 40% above last quarter's weekly average. Merino beanies are still selling despite warming weather, likely gift purchases. Consider running a promotion on winter accessories before seasonal demand drops completely.",
    },
  },
  3: {
    id: 3,
    week_start: "2026-02-17",
    payload: {
      top_sellers: [
        { sku: "BLK-TEE-M", title: "Classic Black Tee — Medium", units_sold: 65 },
        { sku: "GRY-JOGGER-L", title: "Grey Slim Jogger — Large", units_sold: 39 },
        { sku: "ORG-POLO-M", title: "Organic Cotton Polo — Medium", units_sold: 27 },
      ],
      stockouts: [],
      low_sku_count: 6,
      ai_commentary: "Clean week with no stockouts. Organic cotton polo is gaining traction — first time in the top 3 sellers. GreenThread delivery for organic fabrics is scheduled next week which should replenish the polo inventory. Overall healthy stock levels across the catalog.",
    },
  },
  4: {
    id: 4,
    week_start: "2026-02-10",
    payload: {
      top_sellers: [
        { sku: "WHT-HOODIE-M", title: "White Pullover Hoodie — Medium", units_sold: 58 },
        { sku: "BLK-TEE-L", title: "Classic Black Tee — Large", units_sold: 44 },
        { sku: "FRT-SWT-M", title: "French Terry Sweatshirt — Medium", units_sold: 31 },
      ],
      stockouts: [
        { sku: "WHT-HOODIE-L", title: "White Pullover Hoodie — Large", triggered_at: "2026-02-12T09:30:00Z" },
      ],
      low_sku_count: 9,
      ai_commentary: "Valentine's week drove hoodie and sweatshirt sales significantly higher. The white hoodie in large stocked out mid-week — recommend increasing the large size allocation by 30% for Pacific Textile orders. French terry sweatshirt is a new entry to the top sellers list, suggesting the product launch is resonating.",
    },
  },
  5: {
    id: 5,
    week_start: "2026-02-03",
    payload: {
      top_sellers: [
        { sku: "BLK-TEE-M", title: "Classic Black Tee — Medium", units_sold: 61 },
        { sku: "LTH-BLT-M", title: "Leather Belt — Medium (32-34)", units_sold: 28 },
        { sku: "SLM-CHN-32", title: "Slim Fit Chinos — 32", units_sold: 24 },
      ],
      stockouts: [],
      low_sku_count: 5,
      ai_commentary: "Stable week. Black tee remains the unshakeable top seller. Leather belts and chinos are performing well together — consider creating a bundle offer. Inventory levels are the healthiest they've been in the past month.",
    },
  },
};

const PURCHASE_ORDERS = [
  {
    id: 101, status: "sent", order_date: "2026-03-08", expected_delivery: "2026-03-22",
    draft_body: "Hi Sarah,\n\nPlease process our reorder for the following cotton basics:\n\n- BLK-TEE-M x 100 @ $8.50\n- BLK-TEE-L x 75 @ $8.50\n- RED-SOCK-M x 200 @ $3.25\n\nTotal: $1,537.50\nExpected delivery: March 22, 2026\n\nThank you,\nInventory Intelligence",
    supplier: { id: 1, name: "Pacific Textile Co." },
    line_items: [
      { id: 1, sku: "BLK-TEE-M", quantity_ordered: 100, unit_price: 8.5, variant: { title: "Medium", product: { title: "Classic Black Tee" } } },
      { id: 2, sku: "BLK-TEE-L", quantity_ordered: 75, unit_price: 8.5, variant: { title: "Large", product: { title: "Classic Black Tee" } } },
      { id: 9, sku: "RED-SOCK-M", quantity_ordered: 200, unit_price: 3.25, variant: { title: "Medium", product: { title: "Red Crew Socks" } } },
    ],
  },
  {
    id: 102, status: "draft", order_date: "2026-03-10", expected_delivery: "2026-03-31",
    draft_body: "Hi Marcus,\n\nPlease find our reorder for denim jackets attached.\n\nItems:\n- DNM-JKT-S x 50 @ $24.00\n- DNM-JKT-M x 40 @ $24.00\n- OLV-CARGO-32 x 60 @ $18.50\n\nTotal: $3,270.00\nExpected delivery: March 31, 2026\n\nThanks,\nInventory Intelligence",
    supplier: { id: 2, name: "Urban Stitch MFG" },
    line_items: [
      { id: 3, sku: "DNM-JKT-S", quantity_ordered: 50, unit_price: 24.0, variant: { title: "Small", product: { title: "Denim Trucker Jacket" } } },
      { id: 4, sku: "DNM-JKT-M", quantity_ordered: 40, unit_price: 24.0, variant: { title: "Medium", product: { title: "Denim Trucker Jacket" } } },
      { id: 5, sku: "OLV-CARGO-32", quantity_ordered: 60, unit_price: 18.5, variant: { title: "32", product: { title: "Olive Cargo Pant" } } },
    ],
  },
  {
    id: 103, status: "sent", order_date: "2026-03-05", expected_delivery: "2026-03-12",
    draft_body: null,
    supplier: { id: 3, name: "QuickShip Accessories" },
    line_items: [
      { id: 6, sku: "NVY-CAP-OS", quantity_ordered: 150, unit_price: 6.75, variant: { title: "One Size", product: { title: "Navy Baseball Cap" } } },
      { id: 7, sku: "BEG-TOTE-OS", quantity_ordered: 80, unit_price: 11.0, variant: { title: "One Size", product: { title: "Beige Canvas Tote" } } },
    ],
  },
  {
    id: 104, status: "sent", order_date: "2026-02-28", expected_delivery: "2026-03-28",
    draft_body: null,
    supplier: { id: 4, name: "Nordic Knit Works" },
    line_items: [
      { id: 8, sku: "MRN-BNE-OS", quantity_ordered: 100, unit_price: 9.0, variant: { title: "One Size", product: { title: "Merino Wool Beanie" } } },
      { id: 10, sku: "CSH-SCRV-OS", quantity_ordered: 40, unit_price: 32.0, variant: { title: "One Size", product: { title: "Cashmere Scarf" } } },
    ],
  },
  {
    id: 105, status: "draft", order_date: "2026-03-10", expected_delivery: "2026-03-28",
    draft_body: "Hi David,\n\nWe'd like to reorder the following footwear:\n\n- AIR-MAX-10 x 30 @ $68.00\n- AIR-MAX-9 x 25 @ $68.00\n- WHT-SNKR-9 x 20 @ $52.00\n\nTotal: $4,780.00\nExpected delivery: March 28, 2026\n\nBest,\nInventory Intelligence",
    supplier: { id: 5, name: "SoleTech Industries" },
    line_items: [
      { id: 11, sku: "AIR-MAX-10", quantity_ordered: 30, unit_price: 68.0, variant: { title: "10", product: { title: "Air Max Runner" } } },
      { id: 12, sku: "AIR-MAX-9", quantity_ordered: 25, unit_price: 68.0, variant: { title: "9", product: { title: "Air Max Runner" } } },
      { id: 13, sku: "WHT-SNKR-9", quantity_ordered: 20, unit_price: 52.0, variant: { title: "9", product: { title: "White Low-Top Sneaker" } } },
    ],
  },
];

const WEBHOOK_ENDPOINTS = [
  { id: 1, url: "https://hooks.slack.com/services/T00/B00/xxxyyyzzz", event_type: "low_stock", is_active: true },
  { id: 2, url: "https://myshop.com/webhooks/oos-alert", event_type: "out_of_stock", is_active: true },
  { id: 3, url: "https://hooks.slack.com/services/T00/C11/aabbccdd", event_type: "low_stock", is_active: false },
  { id: 4, url: "https://myshop.com/webhooks/inventory-sync", event_type: "low_stock", is_active: true },
];

/* ═══════════════════════════════════════════════════
   Route Matching & Response Logic
   ═══════════════════════════════════════════════════ */

const MOCK_DATA: Record<string, unknown> = {
  // ── Dashboard ──
  "/shop": {
    total_skus: 142,
    low_stock_count: 8,
    out_of_stock_count: 3,
    synced_at: "2026-03-10T14:22:00Z",
    low_stock_items: LOW_STOCK_ITEMS,
  },

  // ── Suppliers ──
  "/suppliers": {
    suppliers: SUPPLIERS,
  },

  // ── Reports list ──
  "/reports": {
    reports: REPORTS,
  },

  // ── Purchase Orders ──
  "/purchase_orders": {
    purchase_orders: PURCHASE_ORDERS,
  },

  // ── Settings ──
  "/settings": {
    alert_email: "alerts@myshop.com",
    low_stock_threshold: 10,
    timezone: "America/Toronto",
    weekly_report_day: "monday",
  },

  // ── Webhooks ──
  "/webhook_endpoints": {
    webhook_endpoints: WEBHOOK_ENDPOINTS,
  },
};

// Add individual report detail routes
for (const [id, detail] of Object.entries(REPORT_DETAILS)) {
  MOCK_DATA[`/reports/${id}`] = detail;
}

function getProductsResponse(page: number, _filter?: string) {
  const pageData = PAGES[page] || [];
  const totalCount = PRODUCTS_PAGE_1.length + PRODUCTS_PAGE_2.length + PRODUCTS_PAGE_3.length;
  return {
    products: pageData,
    meta: {
      current_page: page,
      total_pages: 3,
      total_count: totalCount,
      per_page: 10,
    },
  };
}

function handlePost(path: string): unknown {
  if (path === "/inventory/sync") {
    return { status: "ok", synced_at: new Date().toISOString() };
  }
  if (path === "/reports/generate") {
    return { id: REPORTS.length + 1, week_start: "2026-03-10", created_at: new Date().toISOString(), emailed_at: null };
  }
  if (path === "/purchase_orders/generate_draft") {
    return {
      id: 200,
      status: "draft",
      order_date: new Date().toISOString().split("T")[0],
      expected_delivery: "2026-04-01",
      draft_body: "Hi,\n\nPlease process our reorder based on current low-stock items:\n\n- BLK-TEE-M x 120 @ $8.50\n- WHT-HOODIE-L x 80 @ $18.00\n- GRY-JOGGER-XL x 50 @ $15.00\n\nTotal: $2,710.00\nExpected delivery: April 1, 2026\n\nGenerated by Inventory Intelligence AI\n\nBest regards",
      supplier: { id: 1, name: "Pacific Textile Co." },
      line_items: [
        { id: 100, sku: "BLK-TEE-M", quantity_ordered: 120, unit_price: 8.5, variant: { title: "Medium", product: { title: "Classic Black Tee" } } },
        { id: 101, sku: "WHT-HOODIE-L", quantity_ordered: 80, unit_price: 18.0, variant: { title: "Large", product: { title: "White Pullover Hoodie" } } },
        { id: 102, sku: "GRY-JOGGER-XL", quantity_ordered: 50, unit_price: 15.0, variant: { title: "XL", product: { title: "Grey Slim Jogger" } } },
      ],
    };
  }
  // send_email
  if (path.match(/\/purchase_orders\/\d+\/send_email/)) {
    return { status: "sent" };
  }
  // webhook create
  if (path === "/webhook_endpoints") {
    return { id: WEBHOOK_ENDPOINTS.length + 1, url: "https://new-endpoint.com/hook", event_type: "low_stock", is_active: true };
  }
  return { status: "ok" };
}

export function useAuthenticatedFetch() {
  return useCallback(async (path: string, options: RequestInit = {}) => {
    // Simulate network delay
    await new Promise((r) => setTimeout(r, 300));

    const method = (options.method || "GET").toUpperCase();

    // Handle mutations
    if (method !== "GET") {
      const basePath = path.split("?")[0];
      return structuredClone(handlePost(basePath));
    }

    // Strip query params for lookup, but extract page/filter
    const url = new URL(path, "http://localhost");
    const basePath = url.pathname;
    const page = parseInt(url.searchParams.get("page") || "1", 10);
    const filter = url.searchParams.get("filter") || undefined;

    // Products endpoint — paginated
    if (basePath === "/products") {
      return structuredClone(getProductsResponse(page, filter));
    }

    // PATCH /settings — return updated settings
    if (basePath === "/settings" && method === "PATCH") {
      return structuredClone(MOCK_DATA["/settings"]);
    }

    const data = MOCK_DATA[basePath];
    if (data) return structuredClone(data);

    // Fallback empty
    return {};
  }, []);
}
