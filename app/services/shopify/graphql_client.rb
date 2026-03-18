# frozen_string_literal: true

module Shopify
  class GraphqlClient
    MAX_RETRIES = 3
    THROTTLE_SLEEP = 2.0

    class ShopifyThrottledError < StandardError; end
    class ShopifyApiError < StandardError; end

    def initialize(shop)
      @shop = shop
      @client = ShopifyAPI::Clients::Graphql::Admin.new(
        session: build_session
      )
    end

    def query(graphql_query, variables: {})
      retries = 0
      begin
        response = @client.query(query: graphql_query, variables: variables)

        if response.body['errors']
          errors = response.body['errors']
          throttled = errors.any? { |e| e.dig('extensions', 'code') == 'THROTTLED' }
          raise ShopifyThrottledError, 'Rate limited by Shopify' if throttled


          raise ShopifyApiError, errors.map { |e| e['message'] }.join(', ')

        end

        response.body['data']
      rescue ShopifyThrottledError => e
        retries += 1
        if retries <= MAX_RETRIES
          sleep(THROTTLE_SLEEP * retries)
          retry
        end
        raise e
      end
    end

    def paginate(graphql_query, connection_path:, variables: {})
      all_nodes = []
      cursor = nil

      loop do
        data = query(graphql_query, variables: variables.merge(cursor: cursor))
        connection = data.dig(*connection_path)
        break unless connection

        all_nodes.concat(connection['nodes'] || connection['edges']&.map { |e| e['node'] } || [])

        page_info = connection['pageInfo']
        break unless page_info&.dig('hasNextPage')

        cursor = page_info['endCursor']
      end

      all_nodes
    end

    private

    def build_session
      ShopifyAPI::Auth::Session.new(
        shop: @shop.shop_domain,
        access_token: @shop.access_token
      )
    end
  end
end
