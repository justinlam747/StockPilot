# frozen_string_literal: true

FactoryBot.define do
  factory :purchase_order_line_item do
    purchase_order
    variant
    sku { "SKU-#{SecureRandom.hex(4).upcase}" }
    qty_ordered { 10 }
    unit_price { 9.99 }
  end
end
