# frozen_string_literal: true

namespace :agents do
  desc 'Run the inventory monitor agent for all active shops'
  task check: :environment do
    puts 'Running inventory monitor agent...'
    results = Agents::Runner.run_all_shops

    results.each do |result|
      puts "\n--- #{result[:shop]} ---"
      result[:log]&.each { |line| puts "  #{line}" }
      puts "  Turns: #{result[:turns]}" if result[:turns]
      puts "  ERROR: #{result[:error]}" if result[:error].is_a?(String)
    end

    puts "\nDone. Checked #{results.size} shop(s)."
  end

  desc 'Run the inventory monitor agent for a specific shop'
  task :check_shop, [:shop_id] => :environment do |_t, args|
    shop_id = args[:shop_id] || ENV.fetch('SHOP_ID', nil)
    abort 'Usage: rake agents:check_shop[SHOP_ID]' unless shop_id

    puts "Running inventory monitor agent for shop #{shop_id}..."
    result = Agents::Runner.run_for_shop(shop_id.to_i)

    result[:log]&.each { |line| puts "  #{line}" }
    puts "Turns: #{result[:turns]}" if result[:turns]
    puts "\nDone."
  end
end
