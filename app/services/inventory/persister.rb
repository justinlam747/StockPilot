# frozen_string_literal: true

module Inventory
  # Upserts products and variants from Shopify GraphQL data.
  class Persister
    def initialize(shop)
      @shop = shop
      @cache = Cache::ShopCache.new(shop)
    end

    def upsert(data)
      data[:products].each do |product_node|
        product = upsert_product_from_graphql(product_node)
        @cache.write_product(product.reload) if product
      end
      @cache.invalidate_inventory
    end

    def upsert_single_product(shopify_data)
      product = find_or_init_product(shopify_data['id'].to_s)
      assign_product_attrs(product, shopify_data)
      product.save!
      upsert_webhook_variants(product, shopify_data['variants'] || [])
      product
    end

    private

    def find_or_init_product(shopify_id)
      Product.find_or_initialize_by(shopify_product_id: shopify_id)
    end

    def assign_product_attrs(product, data)
      product.assign_attributes(
        title: data['title'],
        product_type: data['product_type'] || data['productType'],
        vendor: data['vendor'],
        status: (data['status'] || 'active').downcase,
        deleted_at: nil,
        synced_at: Time.current
      )
    end

    def upsert_webhook_variants(product, variants_data)
      variants_data.each do |vd|
        variant = Variant.find_or_initialize_by(shopify_variant_id: vd['id'].to_s)
        variant.assign_attributes(
          product: product, sku: vd['sku'],
          title: vd['title'], price: vd['price'].to_f
        )
        variant.save!
      end
    end

    def upsert_product_from_graphql(node)
      product = find_or_init_product(node['legacyResourceId'].to_s)
      assign_graphql_product_attrs(product, node)
      product.save!
      upsert_graphql_variants(product, node.dig('variants', 'nodes') || [])
      product
    end

    def assign_graphql_product_attrs(product, node)
      product.assign_attributes(
        title: node['title'],
        product_type: node['productType'],
        vendor: node['vendor'],
        status: node['status']&.downcase || 'active',
        deleted_at: nil,
        synced_at: Time.current
      )
    end

    def upsert_graphql_variants(product, variant_nodes)
      variant_nodes.each do |vnode|
        variant = Variant.find_or_initialize_by(
          shopify_variant_id: vnode['legacyResourceId'].to_s
        )
        variant.assign_attributes(
          product: product, sku: vnode['sku'],
          title: vnode['title'], price: vnode['price'].to_f
        )
        variant.save!
      end
    end
  end
end
