# frozen_string_literal: true

FactoryBot.define do
  factory :inventory_snapshot do
    shop
    variant
    available { 50 }
    on_hand { 55 }
    committed { 5 }
    incoming { 0 }
    snapshotted_at { Time.current }
  end
end
