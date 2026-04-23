# frozen_string_literal: true

namespace :agents do
  desc 'Run the inventory monitor agent for all active shops'
  task check: :environment do
    puts 'Queueing inventory monitor agent for all active shops...'
    runs = Agents::Runner.run_all_shops

    runs.each do |run|
      verb = run.previously_new_record? ? 'queued run' : 'active run'
      puts "  #{run.shop.shop_domain}: #{verb} ##{run.id}"
    end

    puts "\nDone. Queued #{runs.size} run(s)."
  end

  desc 'Run the inventory monitor agent for a specific shop'
  task :check_shop, [:shop_id] => :environment do |_t, args|
    shop_id = args[:shop_id] || ENV.fetch('SHOP_ID', nil)
    abort 'Usage: rake agents:check_shop[SHOP_ID]' unless shop_id

    run = Agents::Runner.run_for_shop(shop_id.to_i)
    verb = run.previously_new_record? ? 'Queued' : 'Reused active'
    puts "#{verb} inventory monitor run ##{run.id} for #{run.shop.shop_domain}."
  end
end
