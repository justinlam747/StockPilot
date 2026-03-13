FactoryBot.define do
  factory :customer do
    shop
    sequence(:shopify_customer_id) { |n| 5000 + n }
    email { "customer#{SecureRandom.hex(4)}@example.com" }
    first_name { "Test" }
    last_name { "Customer" }
  end
end
