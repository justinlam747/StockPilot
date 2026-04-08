# frozen_string_literal: true

module Demo
  class Seeder
    DEMO_DOMAIN = 'demo.myshopify.com'
    DEMO_TOKEN = 'demo_token_not_real'
    DEMO_CLERK_ID = 'demo_user'
    SNAPSHOT_DAYS = 30

    def seed!
      ActsAsTenant.without_tenant do
        return if Shop.exists?(shop_domain: DEMO_DOMAIN)

        ActiveRecord::Base.transaction do
          create_demo_user_and_shop
          create_suppliers
          create_products_and_variants
          link_variants_to_suppliers
          generate_snapshots_bulk
          generate_alerts
          generate_purchase_orders
        end
      end
    end

    def reset!
      ActsAsTenant.without_tenant do
        demo_shop = Shop.find_by(shop_domain: DEMO_DOMAIN)
        if demo_shop
          demo_user = demo_shop.user
          purge_shop_data!(demo_shop)
          demo_shop.delete
          demo_user&.delete if demo_user&.clerk_user_id == DEMO_CLERK_ID
        end
        seed!
      end
    end

    # SQL-level deletion in dependency order to avoid AR callback issues
    # (Variant has dependent: :restrict_with_error on purchase_order_line_items).
    def purge_shop_data!(shop)
      # Nullify user FK to this shop before deleting
      User.where(active_shop_id: shop.id).update_all(active_shop_id: nil)
      PurchaseOrderLineItem.where(
        purchase_order_id: PurchaseOrder.where(shop_id: shop.id).select(:id)
      ).delete_all
      PurchaseOrder.where(shop_id: shop.id).delete_all
      Alert.where(shop_id: shop.id).delete_all
      InventorySnapshot.where(shop_id: shop.id).delete_all
      Variant.where(shop_id: shop.id).delete_all
      Product.where(shop_id: shop.id).delete_all
      Supplier.where(shop_id: shop.id).delete_all
      AuditLog.where(shop_id: shop.id).delete_all
    end

    private

    def create_demo_user_and_shop
      @demo_user = User.create_or_find_by!(clerk_user_id: DEMO_CLERK_ID) do |u|
        u.email = 'demo@stockpilot.app'
        u.name = 'Demo User'
        u.store_name = 'Evergreen Goods Co.'
        u.store_category = 'apparel'
        u.onboarding_step = 4
        u.onboarding_completed_at = Time.current
      end

      @demo_shop = Shop.create!(
        shop_domain: DEMO_DOMAIN,
        access_token: DEMO_TOKEN,
        user: @demo_user,
        plan: 'professional',
        settings: {
          'low_stock_threshold' => 10,
          'timezone' => 'America/New_York',
          'alert_email' => 'team@evergreen-goods.co'
        }
      )

      @demo_user.update!(active_shop_id: @demo_shop.id)
    end

    def create_suppliers
      @suppliers = {}
      DataCatalog.suppliers.each do |s_data|
        supplier = Supplier.create!(
          shop: @demo_shop,
          name: s_data[:name],
          email: s_data[:email],
          contact_name: s_data[:contact_name],
          lead_time_days: s_data[:lead_time_days],
          star_rating: s_data[:star_rating] || 0,
          rating_notes: s_data[:rating_notes]
        )
        @suppliers[s_data[:name]] = supplier
      end
    end

    def create_products_and_variants
      @variants_with_profiles = []
      shopify_product_id = 900_000

      DataCatalog.products.each do |p_data|
        shopify_product_id += 1
        product = Product.create!(
          shop: @demo_shop,
          shopify_product_id: shopify_product_id,
          title: p_data[:title],
          product_type: p_data[:type],
          vendor: p_data[:vendor],
          status: 'active',
          synced_at: Time.current
        )

        shopify_variant_id = shopify_product_id * 100
        p_data[:variants].each do |v_name|
          shopify_variant_id += 1
          price = rand(p_data[:price_range])
          sku = generate_sku(p_data[:vendor], p_data[:title], v_name)

          variant = Variant.create!(
            shop: @demo_shop,
            product: product,
            shopify_variant_id: shopify_variant_id,
            sku: sku,
            title: v_name,
            price: price,
            low_stock_threshold: [5, 10, 15].sample
          )

          profile = assign_stock_profile
          @variants_with_profiles << [variant, profile]
        end
      end
    end

    def link_variants_to_suppliers
      DataCatalog.vendor_supplier_map.each do |vendor, supplier_name|
        supplier = @suppliers[supplier_name]
        next unless supplier

        Variant.joins(:product)
               .where(shop_id: @demo_shop.id, products: { vendor: vendor })
               .update_all(supplier_id: supplier.id)
      end
    end

    def generate_snapshots_bulk
      rows = []
      now = Time.current

      @variants_with_profiles.each do |variant, profile|
        initial_stock = rand(profile[:range].max..(profile[:range].max + 80))
        daily_sell_rate = case profile[:key]
                          when :healthy then rand(1..4)
                          when :low then rand(4..8)
                          when :out then rand(5..10)
                          when :trending_down then rand(3..6)
                          else rand(1..4)
                          end

        running_stock = initial_stock

        SNAPSHOT_DAYS.downto(0).each do |days_ago|
          sold_today = (daily_sell_rate * rand(0.3..1.8)).round
          running_stock = [running_stock - sold_today, 0].max

          if days_ago == 15 && rand < 0.3
            running_stock += rand(40..100)
          end

          rows << {
            shop_id: @demo_shop.id,
            variant_id: variant.id,
            available: running_stock,
            on_hand: running_stock + rand(0..5),
            committed: rand(0..3),
            incoming: days_ago < 7 ? rand(0..20) : 0,
            snapshotted_at: (now - days_ago.days),
            created_at: (now - days_ago.days)
          }
        end
      end

      InventorySnapshot.insert_all(rows)
    end

    def generate_alerts
      low_stock_variants = @variants_with_profiles
        .select { |_v, p| p[:key] == :low || p[:key] == :out }
        .map(&:first)

      low_stock_variants.sample([low_stock_variants.size, 15].min).each do |variant|
        rand(1..3).times do |i|
          latest_snapshot = InventorySnapshot.where(shop_id: @demo_shop.id, variant_id: variant.id)
                                             .order(snapshotted_at: :desc).first
          is_out = latest_snapshot && latest_snapshot.available <= 0

          Alert.create!(
            shop: @demo_shop,
            variant: variant,
            alert_type: is_out ? 'out_of_stock' : 'low_stock',
            channel: 'email',
            status: 'sent',
            threshold: variant.low_stock_threshold || 10,
            current_quantity: latest_snapshot&.available || rand(0..8),
            triggered_at: rand(7).days.ago + rand(24).hours,
            dismissed: i > 1
          )
        end
      end
    end

    def generate_purchase_orders
      supplier_list = @suppliers.values.sample(6)
      statuses = %w[draft draft sent sent received received received received]

      supplier_list.each_with_index do |supplier, idx|
        status = statuses[idx] || 'received'
        sent_at = status == 'sent' ? rand(14).days.ago : (status == 'received' ? rand(30).days.ago : nil)

        po = PurchaseOrder.create!(
          shop: @demo_shop,
          supplier: supplier,
          po_number: format('PO-%d-%04d', @demo_shop.id, idx + 1),
          status: status,
          order_date: (sent_at || Time.current).to_date - rand(3..7).days,
          expected_delivery: Date.current + rand(7..30).days,
          sent_at: sent_at,
          po_notes: status == 'draft' ? 'Auto-generated by StockPilot' : nil,
          draft_body: "Dear #{supplier.contact_name},\n\nPlease find attached our purchase order.\n\nBest regards,\nEvergreen Goods Co."
        )

        supplier_variants = Variant.where(shop_id: @demo_shop.id, supplier_id: supplier.id)
        supplier_variants.sample([supplier_variants.count, rand(2..5)].min).each do |v|
          qty = rand(20..100)
          PurchaseOrderLineItem.create!(
            purchase_order: po,
            variant: v,
            sku: v.sku,
            title: "#{v.product.title} — #{v.title}",
            qty_ordered: qty,
            qty_received: status == 'received' ? qty : 0,
            unit_price: v.price || rand(10..50)
          )
        end
      end
    end

    def assign_stock_profile
      profiles = DataCatalog.stock_profiles
      roll = rand
      cumulative = 0.0
      profiles.each do |key, config|
        cumulative += config[:pct]
        return { key: key, range: config[:range] } if roll <= cumulative
      end
      { key: :healthy, range: profiles[:healthy][:range] }
    end

    def generate_sku(vendor, title, variant_name)
      prefix = vendor.split.map { |w| w[0] }.join.upcase[0..2]
      product_code = title.split.map { |w| w[0] }.join.upcase[0..1]
      variant_code = variant_name.gsub(/[^a-zA-Z0-9]/, '').upcase[0..1]
      "#{prefix}-#{product_code}-#{variant_code}"
    end
  end
end
