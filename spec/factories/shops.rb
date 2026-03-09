FactoryBot.define do
  factory :shop do
    sequence(:shop_domain) { |n| "test-shop-#{n}.myshopify.com" }
    access_token { "shpat_test_token_#{SecureRandom.hex(16)}" }
    installed_at { Time.current }
    settings { { "low_stock_threshold" => 10, "timezone" => "America/Toronto" } }
  end
end
