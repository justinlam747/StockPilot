# Seed data for StockPilot development
# Run: rails db:seed

puts "Seeding StockPilot development data..."

# Find or create the dev shop
shop = Shop.find_or_create_by!(shop_domain: "dev-store.myshopify.com") do |s|
  s.access_token = "dev-token"
  s.installed_at = Time.current
end

ActsAsTenant.with_tenant(shop) do
  # ── Suppliers ──
  suppliers = [
    { name: "Pacific Textiles Co.", email: "orders@pacifictextiles.com", contact_name: "Sarah Chen", lead_time_days: 14, star_rating: 5 },
    { name: "Nordic Craft Supply", email: "hello@nordiccraft.eu", contact_name: "Erik Lindberg", lead_time_days: 21, star_rating: 4 },
    { name: "Urban Materials Ltd", email: "sales@urbanmaterials.co", contact_name: "James Wright", lead_time_days: 7, star_rating: 3 },
    { name: "Sakura Imports", email: "info@sakuraimports.jp", contact_name: "Yuki Tanaka", lead_time_days: 28, star_rating: 4 },
    { name: "Verde Organics", email: "supply@verdeorganics.com", contact_name: "Maria Santos", lead_time_days: 10, star_rating: 5 },
  ]

  created_suppliers = suppliers.map do |attrs|
    Supplier.find_or_create_by!(name: attrs[:name]) do |s|
      s.assign_attributes(attrs)
    end
  end

  puts "  Created #{created_suppliers.size} suppliers"

  # ── Products & Variants ──
  products_data = [
    { title: "Classic Cotton T-Shirt", product_type: "Apparel", vendor: "Pacific Textiles Co.", status: "active",
      variants: [
        { title: "Small / White", sku: "TSH-WHT-S", price: 29.99, stock: 45 },
        { title: "Medium / White", sku: "TSH-WHT-M", price: 29.99, stock: 62 },
        { title: "Large / White", sku: "TSH-WHT-L", price: 29.99, stock: 8 },
        { title: "Small / Black", sku: "TSH-BLK-S", price: 29.99, stock: 31 },
        { title: "Medium / Black", sku: "TSH-BLK-M", price: 29.99, stock: 0 },
      ] },
    { title: "Merino Wool Sweater", product_type: "Apparel", vendor: "Nordic Craft Supply", status: "active",
      variants: [
        { title: "S / Navy", sku: "SWT-NAV-S", price: 89.00, stock: 12 },
        { title: "M / Navy", sku: "SWT-NAV-M", price: 89.00, stock: 3 },
        { title: "L / Navy", sku: "SWT-NAV-L", price: 89.00, stock: 24 },
        { title: "M / Charcoal", sku: "SWT-CHR-M", price: 89.00, stock: 0 },
      ] },
    { title: "Canvas Tote Bag", product_type: "Accessories", vendor: "Urban Materials Ltd", status: "active",
      variants: [
        { title: "Natural", sku: "TOT-NAT", price: 34.50, stock: 156 },
        { title: "Olive", sku: "TOT-OLV", price: 34.50, stock: 73 },
        { title: "Rust", sku: "TOT-RST", price: 34.50, stock: 5 },
      ] },
    { title: "Ceramic Pour-Over Set", product_type: "Home", vendor: "Sakura Imports", status: "active",
      variants: [
        { title: "Matte White", sku: "CER-WHT", price: 54.00, stock: 18 },
        { title: "Matte Black", sku: "CER-BLK", price: 54.00, stock: 27 },
        { title: "Sage Green", sku: "CER-SGN", price: 58.00, stock: 0 },
      ] },
    { title: "Organic Lip Balm Set", product_type: "Beauty", vendor: "Verde Organics", status: "active",
      variants: [
        { title: "Lavender 3-Pack", sku: "LIP-LAV-3", price: 14.99, stock: 220 },
        { title: "Mint 3-Pack", sku: "LIP-MNT-3", price: 14.99, stock: 185 },
        { title: "Citrus 3-Pack", sku: "LIP-CIT-3", price: 14.99, stock: 94 },
      ] },
    { title: "Linen Button-Down Shirt", product_type: "Apparel", vendor: "Pacific Textiles Co.", status: "active",
      variants: [
        { title: "S / Sand", sku: "LIN-SND-S", price: 68.00, stock: 7 },
        { title: "M / Sand", sku: "LIN-SND-M", price: 68.00, stock: 15 },
        { title: "L / Sand", sku: "LIN-SND-L", price: 68.00, stock: 22 },
        { title: "M / Sky Blue", sku: "LIN-SKY-M", price: 68.00, stock: 0 },
      ] },
    { title: "Recycled Denim Jacket", product_type: "Apparel", vendor: "Urban Materials Ltd", status: "active",
      variants: [
        { title: "S / Indigo", sku: "DNM-IND-S", price: 125.00, stock: 9 },
        { title: "M / Indigo", sku: "DNM-IND-M", price: 125.00, stock: 14 },
        { title: "L / Indigo", sku: "DNM-IND-L", price: 125.00, stock: 6 },
      ] },
    { title: "Hand-Poured Soy Candle", product_type: "Home", vendor: "Verde Organics", status: "active",
      variants: [
        { title: "Cedar & Sage / 8oz", sku: "CND-CDS-8", price: 28.00, stock: 41 },
        { title: "Lavender / 8oz", sku: "CND-LAV-8", price: 28.00, stock: 2 },
        { title: "Vanilla / 12oz", sku: "CND-VAN-12", price: 36.00, stock: 33 },
      ] },
    { title: "Bamboo Sunglasses", product_type: "Accessories", vendor: "Sakura Imports", status: "active",
      variants: [
        { title: "Tortoise", sku: "SUN-TRT", price: 45.00, stock: 28 },
        { title: "Matte Black", sku: "SUN-BLK", price: 45.00, stock: 0 },
        { title: "Honey", sku: "SUN-HNY", price: 45.00, stock: 52 },
      ] },
    { title: "Woven Throw Blanket", product_type: "Home", vendor: "Nordic Craft Supply", status: "active",
      variants: [
        { title: "Oatmeal / Queen", sku: "THR-OAT-Q", price: 79.00, stock: 11 },
        { title: "Charcoal / Queen", sku: "THR-CHR-Q", price: 79.00, stock: 19 },
      ] },
    { title: "Stainless Steel Water Bottle", product_type: "Accessories", vendor: "Urban Materials Ltd", status: "active",
      variants: [
        { title: "500ml / Silver", sku: "BTL-SLV-500", price: 32.00, stock: 88 },
        { title: "750ml / Silver", sku: "BTL-SLV-750", price: 38.00, stock: 64 },
        { title: "500ml / Matte Black", sku: "BTL-BLK-500", price: 34.00, stock: 4 },
      ] },
    { title: "Cork Yoga Mat", product_type: "Fitness", vendor: "Verde Organics", status: "active",
      variants: [
        { title: "Standard / Natural", sku: "YGA-NAT", price: 72.00, stock: 36 },
        { title: "Travel / Natural", sku: "YGA-NAT-T", price: 58.00, stock: 0 },
      ] },
  ]

  variant_id_counter = 100_000
  created_variants = []

  products_data.each_with_index do |pdata, pi|
    product = Product.find_or_create_by!(shopify_product_id: 900_000 + pi) do |p|
      p.title = pdata[:title]
      p.product_type = pdata[:product_type]
      p.vendor = pdata[:vendor]
      p.status = pdata[:status]
      p.synced_at = Time.current
    end
    product.update!(title: pdata[:title], product_type: pdata[:product_type], vendor: pdata[:vendor])

    supplier = created_suppliers.find { |s| s.name == pdata[:vendor] } || created_suppliers.first

    pdata[:variants].each do |vdata|
      variant_id_counter += 1
      variant = Variant.find_or_create_by!(shopify_variant_id: variant_id_counter) do |v|
        v.product = product
        v.supplier = supplier
        v.sku = vdata[:sku]
        v.title = vdata[:title]
        v.price = vdata[:price]
        v.low_stock_threshold = 10
      end
      variant.update!(sku: vdata[:sku], title: vdata[:title], price: vdata[:price], supplier: supplier)

      # Create inventory snapshot
      variant.inventory_snapshots.destroy_all
      InventorySnapshot.create!(
        shop: shop,
        variant: variant,
        available: vdata[:stock],
        on_hand: vdata[:stock] + rand(0..5),
        committed: rand(0..3),
        incoming: vdata[:stock] < 10 ? rand(20..50) : 0,
        snapshotted_at: Time.current
      )

      created_variants << { variant: variant, stock: vdata[:stock] }
    end
  end

  puts "  Created #{products_data.size} products with #{created_variants.size} variants"

  # ── Alerts ──
  Alert.destroy_all

  low_stock_variants = created_variants.select { |cv| cv[:stock].between?(1, 10) }
  out_of_stock_variants = created_variants.select { |cv| cv[:stock] == 0 }

  out_of_stock_variants.each do |cv|
    Alert.create!(
      shop: shop,
      variant: cv[:variant],
      alert_type: "out_of_stock",
      channel: "dashboard",
      status: "sent",
      triggered_at: rand(1..48).hours.ago,
      metadata: {
        "severity" => "critical",
        "message" => "Out of stock: #{cv[:variant].product.title} — #{cv[:variant].title}"
      }
    )
  end

  low_stock_variants.first(5).each do |cv|
    Alert.create!(
      shop: shop,
      variant: cv[:variant],
      alert_type: "low_stock",
      channel: "dashboard",
      status: "sent",
      triggered_at: rand(1..72).hours.ago,
      metadata: {
        "severity" => "warning",
        "message" => "Low stock (#{cv[:stock]} left): #{cv[:variant].product.title} — #{cv[:variant].title}"
      }
    )
  end

  puts "  Created #{Alert.count} alerts"

  # ── Purchase Orders ──
  PurchaseOrder.destroy_all

  [
    { supplier: created_suppliers[0], status: "received", ago: 12.days.ago, po_number: "PO-2026-001" },
    { supplier: created_suppliers[1], status: "sent", ago: 5.days.ago, po_number: "PO-2026-002" },
    { supplier: created_suppliers[2], status: "sent", ago: 3.days.ago, po_number: "PO-2026-003" },
    { supplier: created_suppliers[3], status: "draft", ago: 1.day.ago, po_number: "PO-2026-004" },
    { supplier: created_suppliers[4], status: "draft", ago: 2.hours.ago, po_number: "PO-2026-005" },
  ].each do |po_data|
    po = PurchaseOrder.create!(
      shop: shop,
      supplier: po_data[:supplier],
      status: po_data[:status],
      po_number: po_data[:po_number],
      created_at: po_data[:ago],
      updated_at: po_data[:ago]
    )

    # Add 2-3 line items per PO
    supplier_variants = created_variants.select { |cv| cv[:variant].supplier == po_data[:supplier] }
    supplier_variants.first(3).each do |cv|
      PurchaseOrderLineItem.create!(
        purchase_order: po,
        variant: cv[:variant],
        sku: cv[:variant].sku,
        title: "#{cv[:variant].product.title} — #{cv[:variant].title}",
        qty_ordered: rand(20..100),
        qty_received: po_data[:status] == "received" ? rand(20..100) : 0,
        unit_price: cv[:variant].price * 0.45
      )
    end
  end

  puts "  Created #{PurchaseOrder.count} purchase orders"

  # ── Agent Results ──
  shop.update!(
    last_agent_run_at: 2.hours.ago,
    last_agent_results: {
      "ran_at" => 2.hours.ago.iso8601,
      "low_stock_count" => low_stock_variants.size,
      "out_of_stock_count" => out_of_stock_variants.size,
      "total_variants_scanned" => created_variants.size,
      "alerts_generated" => out_of_stock_variants.size + [low_stock_variants.size, 5].min,
      "recommendations" => [
        "Reorder TSH-BLK-M from Pacific Textiles — 0 units, avg 15 sales/week",
        "SWT-CHR-M has been OOS for 5 days — consider expedited shipping",
        "CND-LAV-8 at 2 units — below threshold of 10"
      ]
    }
  )

  puts "  Updated agent results"
end

puts "Done! Visit http://localhost:3000/dev_login to see the data."
