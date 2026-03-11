import { Card, BlockStack, Text, Box } from "@shopify/polaris";
import type { ReactNode } from "react";

interface StatCardProps {
  label: string;
  value: ReactNode;
}

export default function StatCard({ label, value }: StatCardProps) {
  return (
    <Box minWidth="200px">
      <Card>
        <BlockStack gap="200">
          <Text as="p" variant="bodySm" tone="subdued">{label}</Text>
          <Text as="p" variant="headingLg">{value}</Text>
        </BlockStack>
      </Card>
    </Box>
  );
}
