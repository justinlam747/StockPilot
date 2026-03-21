# frozen_string_literal: true

module Shopify
  # Fetches all products with variant inventory levels via GraphQL pagination.
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
                inventoryItem {
                  id
                  legacyResourceId
                  inventoryLevels(first: 10) {
                    nodes {
                      id
                      quantities(names: ["available", "on_hand", "committed", "incoming"]) {
                        name
                        quantity
                      }
                    }
                  }
                }
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

    def call
      products = @client.paginate(
        PRODUCTS_QUERY,
        connection_path: ['products']
      )

      {
        products: products,
        fetched_at: Time.current
      }
    end
  end
end
