import { useState, useEffect, useCallback } from "react";
import {
  Page,
  Card,
  DataTable,
  Tabs,
  Pagination,
  Spinner,
  InlineStack,
  BlockStack,
  Box,
} from "@shopify/polaris";
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

export default function InventoryPage() {
  const fetch = useAuthenticatedFetch();
  const [products, setProducts] = useState<Product[]>([]);
  const [meta, setMeta] = useState<Meta>({ current_page: 1, total_pages: 1, total_count: 0, per_page: 25 });
  const [loading, setLoading] = useState(true);
  const [selectedTab, setSelectedTab] = useState(0);

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

  const rows = products.flatMap((product) =>
    product.variants.map((variant) => [
      product.title,
      variant.sku || "—",
      variant.title,
      <StatusBadge key={variant.id} status={product.status === "active" ? "active" : "inactive"} />,
    ])
  );

  return (
    <Page title="Inventory">
      <Card>
        <BlockStack gap="400">
          <Tabs tabs={tabs} selected={selectedTab} onSelect={setSelectedTab} />
          {loading ? (
            <Box padding="800">
              <InlineStack align="center">
                <Spinner size="large" />
              </InlineStack>
            </Box>
          ) : (
            <>
              <DataTable
                columnContentTypes={["text", "text", "text", "text"]}
                headings={["Product", "SKU", "Variant", "Status"]}
                rows={rows}
              />
              <InlineStack align="center">
                <Pagination
                  hasPrevious={meta.current_page > 1}
                  hasNext={meta.current_page < meta.total_pages}
                  onPrevious={() => loadProducts(meta.current_page - 1)}
                  onNext={() => loadProducts(meta.current_page + 1)}
                />
              </InlineStack>
            </>
          )}
        </BlockStack>
      </Card>
    </Page>
  );
}
