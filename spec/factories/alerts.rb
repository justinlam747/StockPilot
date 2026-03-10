FactoryBot.define do
  factory :alert do
    shop
    variant
    alert_type { "low_stock" }
    status { "active" }
    threshold { 10 }
    current_quantity { 3 }
    triggered_at { Time.current }
  end
end
