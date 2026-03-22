# frozen_string_literal: true

namespace :data do
  desc 'Create User records for existing Shop records without a user_id'
  task backfill_users: :environment do
    Shop.where(user_id: nil).find_each do |shop|
      user = User.create!(
        clerk_user_id: "migrated_#{shop.id}",
        email: "migrated+#{shop.shop_domain.split('.').first}@stockpilot.com",
        name: shop.shop_domain.split('.').first.titleize,
        store_name: shop.shop_domain.split('.').first.titleize,
        onboarding_step: 4,
        onboarding_completed_at: shop.installed_at || Time.current
      )
      shop.update!(user_id: user.id)
      user.update!(active_shop_id: shop.id)
      puts "Created user #{user.id} for shop #{shop.shop_domain}"
    end
  end
end
