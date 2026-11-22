module Shopify
  class InventoryFetcher
    LEVEL_FIELDS = <<~GRAPHQL
      pageInfo { hasNextPage endCursor }
      nodes { quantities(names: ["available", "on_hand", "committed", "incoming"]) { name quantity } }
    GRAPHQL

    VARIANTS = <<~GRAPHQL
      query InventoryVariants($cursor: String) {
        productVariants(first: 20, after: $cursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            legacyResourceId title sku
            product { legacyResourceId title }
            inventoryItem { id inventoryLevels(first: 10) { #{LEVEL_FIELDS} } }
          }
        }
      }
    GRAPHQL

    MORE_LEVELS = <<~GRAPHQL
      query InventoryLevels($id: ID!, $cursor: String!) {
        inventoryItem(id: $id) { inventoryLevels(first: 100, after: $cursor) { #{LEVEL_FIELDS} } }
      }
    GRAPHQL

    def initialize(shop)
      @client = GraphqlClient.new(shop)
    end

    def each_variant
      cursor = nil
      loop do
        page = @client.query(VARIANTS, { cursor: cursor }).fetch('productVariants')
        page.fetch('nodes').each { |variant| yield variant, quantities(variant.fetch('inventoryItem')) }
        cursor = next_cursor(page)
        break unless cursor
      end
    end

    private

    def quantities(item)
      totals = { 'available' => 0, 'on_hand' => 0, 'committed' => 0, 'incoming' => 0 }
      levels = item.fetch('inventoryLevels')
      loop do
        levels.fetch('nodes').each do |level|
          level.fetch('quantities').each { |q| totals[q['name']] += q.fetch('quantity') if totals.key?(q['name']) }
        end
        cursor = next_cursor(levels)
        break unless cursor
        levels = @client.query(MORE_LEVELS, { id: item.fetch('id'), cursor: cursor }).fetch('inventoryItem').fetch('inventoryLevels')
      end
      totals
    end

    def next_cursor(page)
      info = page.fetch('pageInfo')
      return unless info.fetch('hasNextPage')
      info.fetch('endCursor').presence || raise(GraphqlClient::ApiError, 'Missing Shopify page cursor')
    end
  end
end
