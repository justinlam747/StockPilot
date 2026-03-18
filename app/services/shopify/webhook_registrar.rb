# frozen_string_literal: true

module Shopify
  # Registers required webhook subscriptions via Shopify GraphQL API.
  class WebhookRegistrar
    REQUIRED_TOPICS = %w[
      app/uninstalled
      products/update
      products/delete
    ].freeze

    REGISTER_MUTATION = <<~GQL
      mutation webhookSubscriptionCreate($topic: WebhookSubscriptionTopic!, $webhookSubscription: WebhookSubscriptionInput!) {
        webhookSubscriptionCreate(topic: $topic, webhookSubscription: $webhookSubscription) {
          webhookSubscription { id }
          userErrors { field message }
        }
      }
    GQL

    def self.call(shop)
      new(shop).register_all
    end

    def initialize(shop)
      @shop = shop
      @client = GraphqlClient.new(shop)
    end

    def register_all
      REQUIRED_TOPICS.each { |topic| register(topic) }
    end

    private

    def register(topic)
      @client.query(REGISTER_MUTATION, variables: webhook_variables(topic))
    rescue Shopify::GraphqlClient::ShopifyApiError => e
      Rails.logger.warn("[WebhookRegistrar] Failed to register #{topic}: #{e.message}")
    end

    def webhook_variables(topic)
      {
        topic: topic.tr('/', '_').upcase,
        webhookSubscription: { callbackUrl: webhook_url(topic), format: 'JSON' }
      }
    end

    def webhook_url(topic)
      host = ENV.fetch('SHOPIFY_APP_URL', 'https://localhost:3000')
      "#{host}/webhooks/#{topic.tr('/', '_')}"
    end
  end
end
