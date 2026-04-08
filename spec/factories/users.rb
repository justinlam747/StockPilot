# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:clerk_user_id) { |n| "clerk_user_#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    name { 'Test User' }
    store_name { 'Test Store' }
    onboarding_step { 1 }
  end
end
