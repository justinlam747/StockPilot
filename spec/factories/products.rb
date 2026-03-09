FactoryBot.define do
  factory :product do
    shop
    sequence(:shopify_product_id) { |n| 1000 + n }
    title { "Test Product" }
    status { "active" }
  end
end
