module Shopify
  class GraphqlClient
    class ApiError < StandardError; end

    def initialize(shop)
      @shop = shop
    end

    def query(document, variables)
      4.times do |attempt|
        session = ShopifyAPI::Auth::Session.new(shop: @shop.shop_domain, access_token: @shop.inventory_access_token)
        client = ShopifyAPI::Clients::Graphql::Admin.new(session: session, api_version: '2026-10')
        response = client.query(query: document, variables: variables, tries: 3)
        errors = Array(response.body['errors'])
        return response.body.fetch('data') if errors.empty?
        unless attempt < 3 && errors.all? { |error| error.dig('extensions', 'code') == 'THROTTLED' }
          raise ApiError, 'Shopify rejected the inventory query'
        end
        sleep(2 * (attempt + 1))
      end
    rescue ShopifyAPI::Errors::HttpResponseError => error
      raise ApiError, "Shopify inventory request failed (HTTP #{error.code})", cause: nil
    end
  end
end
