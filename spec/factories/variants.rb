FactoryBot.define do
  factory :variant do
    shop
    product
    sequence(:shopify_variant_id) { |n| 2000 + n }
    sku { "SKU-#{SecureRandom.hex(4).upcase}" }
    title { "Default" }
    price { 19.99 }
  end
end
