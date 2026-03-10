FactoryBot.define do
  factory :weekly_report do
    shop
    week_start { Time.current.beginning_of_week(:monday) }
    payload { { "top_sellers" => [], "stockouts" => [], "low_sku_count" => 0 } }
  end
end
