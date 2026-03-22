# frozen_string_literal: true

module Demo
  module DataCatalog
    module_function

    def products
      PRODUCTS
    end

    def suppliers
      SUPPLIERS
    end

    def stock_profiles
      STOCK_PROFILES
    end

    def vendor_supplier_map
      VENDOR_SUPPLIER_MAP
    end

    SUPPLIERS = [
      { name: 'EcoThread Co', email: 'orders@ecothread.co', contact_name: 'Sarah Chen',
        lead_time_days: 14, star_rating: 5, rating_notes: 'Reliable, consistently on time' },
      { name: 'BlueLoop Denim', email: 'supply@blueloop.com', contact_name: 'Marcus Rivera',
        lead_time_days: 21, star_rating: 4, rating_notes: 'Quality denim, occasional delays' },
      { name: 'Highland Knits', email: 'wholesale@highlandknits.uk', contact_name: 'Fiona MacLeod',
        lead_time_days: 10, star_rating: 5, rating_notes: '98% on-time delivery' },
      { name: 'GreenTech Labs', email: 'b2b@greentech.io', contact_name: 'James Park',
        lead_time_days: 7, star_rating: 3, rating_notes: 'Fast but packaging quality varies' },
      { name: 'Barefoot Supply', email: 'orders@barefoot.supply', contact_name: 'Ana Ferreira',
        lead_time_days: 18, star_rating: 4, rating_notes: 'Handcrafted quality, worth the wait' },
      { name: 'Mountain Roast', email: 'wholesale@mountainroast.co', contact_name: 'David Okafor',
        lead_time_days: 5, star_rating: 5, rating_notes: 'Fastest supplier, always fresh' },
      { name: 'Kyoto Harvest', email: 'export@kyotoharvest.jp', contact_name: 'Yuki Tanaka',
        lead_time_days: 30, star_rating: 4, rating_notes: 'Premium quality, long lead time from Japan' },
      { name: 'SunVolt', email: 'partners@sunvolt.tech', contact_name: 'Li Wei',
        lead_time_days: 14, star_rating: 3, rating_notes: 'Budget-friendly, QC sometimes inconsistent' }
    ].freeze

    VENDOR_SUPPLIER_MAP = {
      'EcoThread Co' => 'EcoThread Co',
      'BlueLoop Denim' => 'BlueLoop Denim',
      'Highland Knits' => 'Highland Knits',
      'GreenTech Labs' => 'GreenTech Labs',
      'Barefoot Supply' => 'Barefoot Supply',
      'Mountain Roast' => 'Mountain Roast',
      'Kyoto Harvest' => 'Kyoto Harvest',
      'SunVolt' => 'SunVolt'
    }.freeze

    STOCK_PROFILES = {
      healthy:       { range: 50..200, pct: 0.60 },
      low:           { range: 2..9,    pct: 0.25 },
      out:           { range: 0..0,    pct: 0.10 },
      trending_down: { range: 15..30,  pct: 0.05 }
    }.freeze

    PRODUCTS = [
      # Apparel — EcoThread Co
      { title: 'Organic Cotton Tee', type: 'Tops', vendor: 'EcoThread Co', price_range: 28..45,
        variants: %w[XS S M L XL 2XL] },
      { title: 'Linen Button-Down', type: 'Tops', vendor: 'EcoThread Co', price_range: 55..75,
        variants: %w[S M L XL] },
      { title: 'Bamboo Tank Top', type: 'Tops', vendor: 'EcoThread Co', price_range: 22..32,
        variants: %w[XS S M L XL] },
      { title: 'Organic Henley', type: 'Tops', vendor: 'EcoThread Co', price_range: 35..48,
        variants: %w[S M L XL] },
      { title: 'Recycled Fleece Hoodie', type: 'Outerwear', vendor: 'EcoThread Co', price_range: 65..85,
        variants: %w[S M L XL 2XL] },
      { title: 'Hemp Polo Shirt', type: 'Tops', vendor: 'EcoThread Co', price_range: 38..52,
        variants: %w[S M L XL] },

      # Denim — BlueLoop Denim
      { title: 'Recycled Denim Jacket', type: 'Outerwear', vendor: 'BlueLoop Denim', price_range: 89..129,
        variants: %w[S M L XL] },
      { title: 'Selvedge Slim Jeans', type: 'Bottoms', vendor: 'BlueLoop Denim', price_range: 78..98,
        variants: %w[28 30 32 34 36] },
      { title: 'Relaxed Fit Chinos', type: 'Bottoms', vendor: 'BlueLoop Denim', price_range: 55..72,
        variants: %w[28 30 32 34 36 38] },
      { title: 'Denim Overshirt', type: 'Tops', vendor: 'BlueLoop Denim', price_range: 68..88,
        variants: %w[S M L XL] },
      { title: 'Wide Leg Trousers', type: 'Bottoms', vendor: 'BlueLoop Denim', price_range: 62..82,
        variants: %w[28 30 32 34 36] },

      # Accessories — Highland Knits
      { title: 'Merino Wool Beanie', type: 'Accessories', vendor: 'Highland Knits', price_range: 24..32,
        variants: ['One Size'] },
      { title: 'Cable Knit Scarf', type: 'Accessories', vendor: 'Highland Knits', price_range: 38..52,
        variants: ['One Size'] },
      { title: 'Lambswool Gloves', type: 'Accessories', vendor: 'Highland Knits', price_range: 28..38,
        variants: %w[S/M L/XL] },
      { title: 'Cashmere Blend Socks', type: 'Accessories', vendor: 'Highland Knits', price_range: 18..24,
        variants: %w[S M L] },
      { title: 'Wool Blend Cardigan', type: 'Outerwear', vendor: 'Highland Knits', price_range: 72..95,
        variants: %w[S M L XL] },
      { title: 'Fair Isle Sweater', type: 'Tops', vendor: 'Highland Knits', price_range: 85..110,
        variants: %w[S M L XL] },

      # Electronics — GreenTech Labs
      { title: 'Bamboo Wireless Charger', type: 'Accessories', vendor: 'GreenTech Labs', price_range: 35..55,
        variants: %w[Black Natural Walnut] },
      { title: 'Recycled Plastic Phone Case', type: 'Accessories', vendor: 'GreenTech Labs', price_range: 22..35,
        variants: ['iPhone 15', 'iPhone 15 Pro', 'Samsung S24', 'Pixel 8'] },
      { title: 'Cork Laptop Sleeve', type: 'Accessories', vendor: 'GreenTech Labs', price_range: 42..58,
        variants: %w[13-inch 15-inch 16-inch] },
      { title: 'USB-C Hub (Recycled Aluminum)', type: 'Accessories', vendor: 'GreenTech Labs', price_range: 48..65,
        variants: ['4-Port', '7-Port'] },
      { title: 'Biodegradable Earbuds', type: 'Audio', vendor: 'GreenTech Labs', price_range: 55..75,
        variants: %w[White Black Sage] },

      # Footwear — Barefoot Supply
      { title: 'Hemp Canvas Sneakers', type: 'Footwear', vendor: 'Barefoot Supply', price_range: 79..110,
        variants: %w[7 8 9 10 11 12] },
      { title: 'Recycled Rubber Sandals', type: 'Footwear', vendor: 'Barefoot Supply', price_range: 45..58,
        variants: %w[7 8 9 10 11 12] },
      { title: 'Cork Sole Boots', type: 'Footwear', vendor: 'Barefoot Supply', price_range: 110..145,
        variants: %w[7 8 9 10 11 12] },
      { title: 'Bamboo Fiber Slip-Ons', type: 'Footwear', vendor: 'Barefoot Supply', price_range: 55..72,
        variants: %w[7 8 9 10 11] },

      # Coffee — Mountain Roast
      { title: 'Single Origin Coffee Beans', type: 'Coffee', vendor: 'Mountain Roast', price_range: 16..24,
        variants: %w[250g 500g 1kg] },
      { title: 'Cold Brew Concentrate', type: 'Coffee', vendor: 'Mountain Roast', price_range: 14..20,
        variants: %w[500ml 1L] },
      { title: 'Espresso Blend', type: 'Coffee', vendor: 'Mountain Roast', price_range: 18..28,
        variants: %w[250g 500g 1kg] },
      { title: 'Decaf Swiss Water Process', type: 'Coffee', vendor: 'Mountain Roast', price_range: 19..26,
        variants: %w[250g 500g] },
      { title: 'Coffee Gift Box', type: 'Coffee', vendor: 'Mountain Roast', price_range: 42..58,
        variants: ['Starter Pack', 'Connoisseur Pack'] },
      { title: 'Reusable Coffee Filter', type: 'Coffee', vendor: 'Mountain Roast', price_range: 12..18,
        variants: ['V60', 'AeroPress', 'Chemex'] },

      # Tea — Kyoto Harvest
      { title: 'Organic Matcha Powder', type: 'Tea', vendor: 'Kyoto Harvest', price_range: 28..42,
        variants: ['30g Tin', '100g Bag'] },
      { title: 'Sencha Green Tea', type: 'Tea', vendor: 'Kyoto Harvest', price_range: 16..24,
        variants: %w[50g 100g 200g] },
      { title: 'Hojicha Roasted Tea', type: 'Tea', vendor: 'Kyoto Harvest', price_range: 14..22,
        variants: %w[50g 100g] },
      { title: 'Genmaicha Brown Rice Tea', type: 'Tea', vendor: 'Kyoto Harvest', price_range: 12..18,
        variants: %w[50g 100g 200g] },
      { title: 'Matcha Whisk Set', type: 'Tea', vendor: 'Kyoto Harvest', price_range: 32..48,
        variants: ['Standard', 'Premium Bamboo'] },

      # Power — SunVolt
      { title: 'Solar Power Bank 10000mAh', type: 'Power', vendor: 'SunVolt', price_range: 45..65,
        variants: %w[Black White Green] },
      { title: 'Portable Solar Panel 20W', type: 'Power', vendor: 'SunVolt', price_range: 68..88,
        variants: ['Foldable', 'Rigid'] },
      { title: 'Solar Garden Lights (4-pack)', type: 'Power', vendor: 'SunVolt', price_range: 28..38,
        variants: %w[Warm Cool Multicolor] },
      { title: 'Hand-Crank Flashlight', type: 'Power', vendor: 'SunVolt', price_range: 18..28,
        variants: %w[Red Black Yellow] },
      { title: 'Solar Bluetooth Speaker', type: 'Power', vendor: 'SunVolt', price_range: 55..72,
        variants: %w[Black Green Sand] }
    ].freeze
  end
end
