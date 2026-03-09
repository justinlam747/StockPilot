import { Page, Layout, Card, Text, BlockStack } from "@shopify/polaris";

export default function DashboardPage() {
  return (
    <Page title="Dashboard">
      <Layout>
        <Layout.Section>
          <BlockStack gap="400">
            <Card>
              <Text as="h2" variant="headingMd">Inventory Overview</Text>
              <Text as="p" variant="bodyMd">Dashboard content goes here.</Text>
            </Card>
          </BlockStack>
        </Layout.Section>
      </Layout>
    </Page>
  );
}
