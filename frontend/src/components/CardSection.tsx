import { Card, BlockStack, InlineStack, Text, Button } from "@shopify/polaris";
import type { ReactNode } from "react";

interface CardSectionProps {
  title: string;
  action?: {
    content: string;
    onAction: () => void;
    loading?: boolean;
  };
  children: ReactNode;
}

export default function CardSection({ title, action, children }: CardSectionProps) {
  return (
    <Card>
      <BlockStack gap="400">
        <InlineStack align="space-between">
          <Text as="h2" variant="headingMd">{title}</Text>
          {action && (
            <Button variant="tertiary" loading={action.loading} onClick={action.onAction}>
              {action.content}
            </Button>
          )}
        </InlineStack>
        {children}
      </BlockStack>
    </Card>
  );
}
