# frozen_string_literal: true

module Shopify
  # Shared Shopify Admin GraphQL client with throttle retry and pagination.
  # Keep transport concerns here so the sync job and webhook registration
  # code paths stay aligned on retries and error handling.
  class GraphqlClient
    MAX_RETRIES = 3
    THROTTLE_SLEEP = 2.0

    class ShopifyThrottledError < StandardError; end
    class ShopifyApiError < StandardError; end

    def initialize(shop)
      @shop = shop
      @client = ShopifyAPI::Clients::Graphql::Admin.new(session: build_session)
    end

    def run_query(graphql_query, variables: {})
      retries = 0
      begin
        send_graphql_request(graphql_query, variables)
      rescue ShopifyThrottledError => e
        retries += 1
        raise e unless retries <= MAX_RETRIES

        sleep(THROTTLE_SLEEP * retries)
        retry
      end
    end

    def paginate(graphql_query, connection_path:, variables: {})
      # Cursor pagination is centralized here so callers can stay focused on
      # business data instead of duplicating the page loop in each service.
      all_nodes = []
      cursor = nil
      loop do
        connection = fetch_connection(graphql_query, connection_path, variables, cursor)
        break unless connection

        all_nodes.concat(extract_nodes(connection))
        cursor = next_cursor(connection)
        break unless cursor
      end
      all_nodes
    end

    private

    def fetch_connection(graphql_query, connection_path, variables, cursor)
      data = run_query(graphql_query, variables: variables.merge(cursor: cursor))
      data.dig(*connection_path)
    end

    def next_cursor(connection)
      return unless connection.dig('pageInfo', 'hasNextPage')

      connection.dig('pageInfo', 'endCursor')
    end

    def send_graphql_request(graphql_query, variables)
      # @client.query is ShopifyAPI's built-in method, not ours
      response = @client.query(query: graphql_query, variables: variables)
      handle_errors(response)
      response.body['data']
    end

    def handle_errors(response)
      errors = response.body['errors']
      return unless errors

      if errors.any? { |e| e.dig('extensions', 'code') == 'THROTTLED' }
        raise ShopifyThrottledError, 'Rate limited by Shopify'
      end

      raise ShopifyApiError, errors.map { |e| e['message'] }.join(', ')
    end

    def extract_nodes(connection)
      connection['nodes'] || connection['edges']&.map { |edge| edge['node'] } || []
    end

    def build_session
      ShopifyAPI::Auth::Session.new(
        shop: @shop.shop_domain,
        access_token: @shop.access_token
      )
    end
  end
end
