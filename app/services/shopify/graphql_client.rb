module Shopify
  class GraphqlClient
    MAX_RETRIES = 3
    THROTTLE_SLEEP = 2.0

    class ShopifyThrottledError < StandardError; end
    class ShopifyApiError < StandardError; end

    def initialize(shop)
      @shop = shop
    end

    def query(graphql_query, variables: {})
      raise NotImplementedError
    end

    def paginate(graphql_query, variables: {}, connection_path:)
      raise NotImplementedError
    end
  end
end
