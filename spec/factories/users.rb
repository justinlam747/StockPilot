# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:clerk_user_id) { |n| "user_clerk_#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    name { 'Test User' }
    onboarding_step { 1 }

    trait :onboarded do
      onboarding_step { 4 }
      onboarding_completed_at { Time.current }
      store_name { 'Test Store' }
      store_category { 'apparel' }
    end

    trait :with_shop do
      onboarded
      after(:create) do |user|
        shop = create(:shop, user: user)
        user.update!(active_shop_id: shop.id)
      end
    end
  end
end
