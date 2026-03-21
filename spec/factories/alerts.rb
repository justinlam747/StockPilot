# frozen_string_literal: true

FactoryBot.define do
  factory :alert do
    shop
    variant
    alert_type { 'low_stock' }
    channel { 'email' }
    status { 'active' }
    threshold { 10 }
    current_quantity { 3 }
    triggered_at { Time.current }
    dismissed { false }
  end
end
