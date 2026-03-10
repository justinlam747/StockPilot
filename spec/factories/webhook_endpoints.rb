FactoryBot.define do
  factory :webhook_endpoint do
    shop
    url { "https://example.com/webhook" }
    event_type { "low_stock" }
    is_active { true }
  end
end
