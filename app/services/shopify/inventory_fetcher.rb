# frozen_string_literal: true

module Shopify
  # Fetches the current catalog slice needed by the audit engine.
  #
  # Keep this query narrow: only fields consumed by audit rules should be
  # requested here so sync stays fast and easy to understand.
  class InventoryFetcher
    PRODUCTS_QUERY = <<~GQL
      query($cursor: String) {
        products(first: 25, after: $cursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id
            legacyResourceId
            title
            productType
            vendor
            status
            featuredMedia {
              preview {
                image {
                  url
                }
              }
            }
            variants(first: 100) {
              nodes {
                id
                legacyResourceId
                sku
                title
                price
                barcode
              }
            }
          }
        }
      }
    GQL

    def initialize(shop)
      @shop = shop
      @client = GraphqlClient.new(shop)
    end

    # Fetches all products and variants needed for catalog auditing.
    def fetch_all_products
      products = @client.paginate(
        PRODUCTS_QUERY,
        connection_path: ['products']
      )

      {
        products: products,
        fetched_at: Time.current
      }
    end
    alias fetch_all_products_with_inventory fetch_all_products
  end
end
