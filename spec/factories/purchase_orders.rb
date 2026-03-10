FactoryBot.define do
  factory :purchase_order do
    shop
    supplier
    status { "draft" }
    order_date { Date.current }
    expected_delivery { Date.current + 14.days }
  end
end
