# frozen_string_literal: true

# Development seed data for Inventory Intelligence
# Run with: bundle exec rails db:seed

return if Rails.env.production?

puts 'Seeding development data...'

# Create a demo shop
shop = Shop.find_or_create_by!(shop_domain: 'demo-store.myshopify.com') do |s|
  s.access_token = 'shpat_demo_token_for_development'
  s.settings = {
    'low_stock_threshold' => 10,
    'timezone' => 'America/Toronto',
    'alert_email' => 'demo@example.com'
  }
end

ActsAsTenant.with_tenant(shop) do
  # Suppliers
  suppliers = [
    { name: 'ACME Wholesale', email: 'orders@acme-wholesale.com', phone: '555-0101', lead_time_days: 7, star_rating: 5 },
    { name: 'Pacific Trading Co', email: 'supply@pacifictrading.com', phone: '555-0102', lead_time_days: 14, star_rating: 4 },
    { name: 'Nordic Imports', email: 'orders@nordicimports.com', phone: '555-0103', lead_time_days: 21, star_rating: 3 }
  ].map do |attrs|
    Supplier.find_or_create_by!(name: attrs[:name]) do |s|
      s.assign_attributes(attrs)
    end
  end

  # Products with variants
  products_data = [
    {
      title: 'Classic Cotton T-Shirt', shopify_product_id: 100_001, product_type: 'Apparel', vendor: 'ACME Wholesale', status: 'active',
      variants: [
        { title: 'Small / White', sku: 'TSH-SM-WHT', price: 24.99, shopify_variant_id: 200_001, qty: 45 },
        { title: 'Medium / White', sku: 'TSH-MD-WHT', price: 24.99, shopify_variant_id: 200_002, qty: 8 },
        { title: 'Large / White', sku: 'TSH-LG-WHT', price: 24.99, shopify_variant_id: 200_003, qty: 0 },
        { title: 'Small / Black', sku: 'TSH-SM-BLK', price: 24.99, shopify_variant_id: 200_004, qty: 32 }
      ]
    },
    {
      title: 'Premium Denim Jeans', shopify_product_id: 100_002, product_type: 'Apparel', vendor: 'Pacific Trading Co', status: 'active',
      variants: [
        { title: '30W / Indigo', sku: 'JNS-30-IND', price: 79.99, shopify_variant_id: 200_010, qty: 15 },
        { title: '32W / Indigo', sku: 'JNS-32-IND', price: 79.99, shopify_variant_id: 200_011, qty: 3 },
        { title: '34W / Indigo', sku: 'JNS-34-IND', price: 79.99, shopify_variant_id: 200_012, qty: 22 }
      ]
    },
    {
      title: 'Organic Green Tea (100 bags)', shopify_product_id: 100_003, product_type: 'Food & Beverage', vendor: 'Nordic Imports', status: 'active',
      variants: [
        { title: 'Default', sku: 'TEA-GRN-100', price: 14.99, shopify_variant_id: 200_020, qty: 120 }
      ]
    },
    {
      title: 'Stainless Steel Water Bottle', shopify_product_id: 100_004, product_type: 'Accessories', vendor: 'ACME Wholesale', status: 'active',
      variants: [
        { title: '500ml / Silver', sku: 'BTL-500-SLV', price: 34.99, shopify_variant_id: 200_030, qty: 5 },
        { title: '750ml / Silver', sku: 'BTL-750-SLV', price: 39.99, shopify_variant_id: 200_031, qty: 0 },
        { title: '500ml / Matte Black', sku: 'BTL-500-BLK', price: 34.99, shopify_variant_id: 200_032, qty: 18 }
      ]
    },
    {
      title: 'Wireless Charging Pad', shopify_product_id: 100_005, product_type: 'Electronics', vendor: 'Pacific Trading Co', status: 'active',
      variants: [
        { title: 'Default', sku: 'CHG-WLS-001', price: 29.99, shopify_variant_id: 200_040, qty: 67 }
      ]
    }
  ]

  products_data.each do |pd|
    supplier = suppliers.find { |s| s.name == pd[:vendor] }
    product = Product.find_or_create_by!(shopify_product_id: pd[:shopify_product_id]) do |p|
      p.title = pd[:title]
      p.product_type = pd[:product_type]
      p.vendor = pd[:vendor]
      p.status = pd[:status]
      p.synced_at = Time.current
    end

    pd[:variants].each do |vd|
      variant = Variant.find_or_create_by!(shopify_variant_id: vd[:shopify_variant_id]) do |v|
        v.product = product
        v.sku = vd[:sku]
        v.title = vd[:title]
        v.price = vd[:price]
        v.supplier = supplier
        v.low_stock_threshold = 10
      end

      # Create inventory snapshots (last 7 days)
      7.downto(0) do |days_ago|
        drift = rand(-3..3)
        qty = [vd[:qty] + drift + (days_ago * rand(0..2)), 0].max
        InventorySnapshot.create!(
          shop: shop,
          variant: variant,
          available: qty,
          on_hand: qty + rand(0..5),
          committed: rand(0..3),
          incoming: days_ago < 3 ? rand(0..20) : 0,
          snapshotted_at: days_ago.days.ago,
          created_at: days_ago.days.ago
        )
      end
    end
  end

  # Create some alerts for low-stock items
  low_stock_variants = Variant.joins(:product).where(products: { status: 'active' })
  low_stock_variants.each do |v|
    latest = InventorySnapshot.where(variant: v).order(created_at: :desc).first
    next unless latest && latest.available < 10

    Alert.find_or_create_by!(variant: v, alert_type: latest.available <= 0 ? 'out_of_stock' : 'low_stock') do |a|
      a.shop = shop
      a.channel = 'email'
      a.status = 'active'
      a.threshold = 10
      a.current_quantity = latest.available
      a.triggered_at = 1.hour.ago
    end
  end

  # Create a draft purchase order
  supplier = suppliers.first
  po = PurchaseOrder.find_or_create_by!(supplier: supplier, status: 'draft') do |p|
    p.shop = shop
    p.order_date = Date.current
    p.expected_delivery = Date.current + supplier.lead_time_days
  end

  if po.line_items.empty?
    Variant.where(supplier: supplier).limit(3).each do |v|
      PurchaseOrderLineItem.create!(
        purchase_order: po,
        variant: v,
        sku: v.sku,
        qty_ordered: 25,
        unit_price: v.price
      )
    end
  end

  puts "  Shop: #{shop.shop_domain}"
  puts "  Suppliers: #{Supplier.count}"
  puts "  Products: #{Product.count}"
  puts "  Variants: #{Variant.count}"
  puts "  Snapshots: #{InventorySnapshot.count}"
  puts "  Alerts: #{Alert.count}"
  puts "  Purchase Orders: #{PurchaseOrder.count}"
end

puts 'Done!'
