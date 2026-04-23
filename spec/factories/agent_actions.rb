# frozen_string_literal: true

FactoryBot.define do
  factory :agent_action do
    association :agent_run
    sequence(:action_type) { |n| "action_#{n}" }
    status { 'proposed' }
    title { 'Review recommendation' }
    details { 'Suggested follow-up action for the merchant.' }
    payload { {} }
  end
end
