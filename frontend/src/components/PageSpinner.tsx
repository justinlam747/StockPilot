import { Page, Box, InlineStack, Spinner } from "@shopify/polaris";

interface PageSpinnerProps {
  title: string;
}

export default function PageSpinner({ title }: PageSpinnerProps) {
  return (
    <Page title={title}>
      <Box padding="800">
        <InlineStack align="center">
          <Spinner size="large" />
        </InlineStack>
      </Box>
    </Page>
  );
}
