module Inventory
  class Persister
    def initialize(shop)
      @shop = shop
    end

    def upsert(data)
      products = data[:products]
      products.each do |product_node|
        upsert_product_from_graphql(product_node)
      end
    end

    def upsert_single_product(shopify_data)
      shopify_id = shopify_data["id"].to_s
      product = Product.find_or_initialize_by(shopify_product_id: shopify_id)
      product.assign_attributes(
        title: shopify_data["title"],
        product_type: shopify_data["product_type"],
        vendor: shopify_data["vendor"],
        status: shopify_data["status"] || "active",
        deleted_at: nil,
        synced_at: Time.current
      )
      product.save!

      (shopify_data["variants"] || []).each do |variant_data|
        variant = Variant.find_or_initialize_by(
          shopify_variant_id: variant_data["id"].to_s
        )
        variant.assign_attributes(
          product: product,
          sku: variant_data["sku"],
          title: variant_data["title"],
          price: variant_data["price"].to_f
        )
        variant.save!
      end

      product
    end

    private

    def upsert_product_from_graphql(node)
      shopify_id = node["legacyResourceId"].to_s
      product = Product.find_or_initialize_by(shopify_product_id: shopify_id)
      product.assign_attributes(
        title: node["title"],
        product_type: node["productType"],
        vendor: node["vendor"],
        status: node["status"]&.downcase || "active",
        deleted_at: nil,
        synced_at: Time.current
      )
      product.save!

      variant_nodes = node.dig("variants", "nodes") || []
      variant_nodes.each do |vnode|
        variant = Variant.find_or_initialize_by(
          shopify_variant_id: vnode["legacyResourceId"].to_s
        )
        variant.assign_attributes(
          product: product,
          sku: vnode["sku"],
          title: vnode["title"],
          price: vnode["price"].to_f
        )
        variant.save!
      end

      product
    end
  end
end
