import { Text } from "@shopify/polaris";

interface EmptyStateProps {
  message: string;
}

export default function EmptyState({ message }: EmptyStateProps) {
  return (
    <Text as="p" variant="bodyMd" tone="subdued">
      {message}
    </Text>
  );
}
