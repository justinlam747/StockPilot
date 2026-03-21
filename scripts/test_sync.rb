STDOUT.sync = true

shop = Shop.find(7747)
puts "Shop: #{shop.shop_domain}"
puts "Token present: #{shop.access_token.present?}"

begin
  puts "Fetching from Shopify API..."
  fetcher = Shopify::InventoryFetcher.new(shop)
  result = fetcher.call
  products = result[:products]
  puts "Products fetched: #{products.size}"

  products.each do |p|
    variants = p.dig("variants", "nodes") || []
    puts "  #{p['title']} (#{variants.size} variants, status: #{p['status']})"
    variants.each do |v|
      levels = v.dig("inventoryItem", "inventoryLevels", "nodes") || []
      available = levels.sum { |l| l["quantities"]&.find { |q| q["name"] == "available" }&.dig("quantity") || 0 }
      puts "    - #{v['title']} | SKU: #{v['sku']} | Available: #{available}"
    end
  end
rescue => e
  puts "ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end
