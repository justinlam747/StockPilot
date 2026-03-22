# frozen_string_literal: true

namespace :demo do
  desc 'Seed demo shop with realistic inventory data'
  task seed: :environment do
    puts 'Seeding demo data...'
    start = Time.current
    Demo::Seeder.new.seed!
    shop = Shop.find_by(shop_domain: 'demo.myshopify.com')
    elapsed = (Time.current - start).round(1)
    puts "Done in #{elapsed}s — #{shop.products.count} products, #{shop.variants.count} variants"
  end

  desc 'Reset demo data (destroy and re-seed)'
  task reset: :environment do
    puts 'Resetting demo data...'
    start = Time.current
    Demo::Seeder.new.reset!
    shop = Shop.find_by(shop_domain: 'demo.myshopify.com')
    elapsed = (Time.current - start).round(1)
    puts "Done in #{elapsed}s — #{shop.products.count} products, #{shop.variants.count} variants"
  end
end
