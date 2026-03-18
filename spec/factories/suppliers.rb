# frozen_string_literal: true

FactoryBot.define do
  factory :supplier do
    shop
    name { 'Test Supplier' }
    email { 'supplier@example.com' }
    lead_time_days { 7 }
  end
end
