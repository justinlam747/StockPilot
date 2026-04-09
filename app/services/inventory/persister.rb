# frozen_string_literal: true

module Inventory
  # Saves products and variants from Shopify into our database.
  #
  # Shopify sends us product data in two different formats:
  #   1. GraphQL batch sync — uses keys like 'legacyResourceId', 'productType'
  #   2. Webhook REST payload — uses keys like 'id', 'product_type'
  #
  # Instead of writing two separate save functions (one per format),
  # we NORMALIZE the data first into a common shape, then save it once.
  # This means there's only one "save" path to understand.
  #
  class Persister
    def initialize(shop)
      @shop = shop
      @cache = Cache::ShopCache.new(shop)
    end

    # Called by InventorySyncJob — saves a batch of products from GraphQL.
    def upsert(data)
      data[:products].each do |product_node|
        product = upsert_single_product(product_node, source: :graphql)
        @cache.write_product(product.reload) if product
      end
      @cache.invalidate_inventory
    end

    # Called by WebhooksController — saves one product from a webhook.
    # Also called by upsert above for each product in a batch.
    #
    # The source: keyword tells normalize which format the data is in:
    #   source: :webhook  -> REST format  (keys like 'id', 'product_type')
    #   source: :graphql  -> GraphQL format (keys like 'legacyResourceId', 'productType')
    #
    def upsert_single_product(raw_data, source:)
      normalized = normalize_product_data(raw_data, source: source)
      product = find_or_initialize_product(normalized[:shopify_id])
      save_product(product, normalized)
      save_variants(product, normalized[:variants])
      product
    end

    private

    # ---- Normalize: turn either format into the same hash shape ----

    def normalize_product_data(raw_data, source:)
      case source
      when :webhook  then normalize_webhook_product(raw_data)
      when :graphql  then normalize_graphql_product(raw_data)
      else raise ArgumentError, "Unknown source: #{source}. Expected :webhook or :graphql"
      end
    end

    def normalize_webhook_product(data)
      {
        shopify_id: data['id'].to_s,
        title: data['title'],
        product_type: data['product_type'] || data['productType'],
        vendor: data['vendor'],
        status: (data['status'] || 'active').downcase,
        image_url: nil,
        variants: (data['variants'] || []).map { |v| normalize_webhook_variant(v) }
      }
    end

    def normalize_graphql_product(node)
      {
        shopify_id: node['legacyResourceId'].to_s,
        title: node['title'],
        product_type: node['productType'],
        vendor: node['vendor'],
        status: node['status']&.downcase || 'active',
        image_url: node.dig('featuredMedia', 'preview', 'image', 'url'),
        variants: (node.dig('variants', 'nodes') || []).map { |v| normalize_graphql_variant(v) }
      }
    end

    def normalize_webhook_variant(data)
      {
        shopify_id: data['id'].to_s,
        sku: data['sku'],
        title: data['title'],
        price: data['price'].to_f
      }
    end

    def normalize_graphql_variant(node)
      {
        shopify_id: node['legacyResourceId'].to_s,
        sku: node['sku'],
        title: node['title'],
        price: node['price'].to_f
      }
    end

    # ---- Save: one path for both formats ----

    # find_or_initialize_by is an ActiveRecord method that either:
    #   - finds an existing record matching the condition, OR
    #   - creates a new (unsaved) record with that value pre-filled.
    # This prevents duplicate products when we sync the same data twice.
    def find_or_initialize_product(shopify_id)
      Product.find_or_initialize_by(shopify_product_id: shopify_id)
    end

    def save_product(product, normalized)
      product.assign_attributes(
        title: normalized[:title],
        product_type: normalized[:product_type],
        vendor: normalized[:vendor],
        status: normalized[:status],
        image_url: normalized[:image_url],
        deleted_at: nil,
        synced_at: Time.current
      )
      product.save!
    end

    def save_variants(product, normalized_variants)
      normalized_variants.each do |variant_data|
        variant = Variant.find_or_initialize_by(shopify_variant_id: variant_data[:shopify_id])
        variant.assign_attributes(
          product: product,
          sku: variant_data[:sku],
          title: variant_data[:title],
          price: variant_data[:price]
        )
        variant.save!
      end
    end
  end
end
