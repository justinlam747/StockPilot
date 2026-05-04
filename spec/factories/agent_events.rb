# frozen_string_literal: true

FactoryBot.define do
  factory :agent_event do
    agent_run
    sequence(:event_type) { |n| "event_#{n}" }
    sequence(:sequence) { |n| n - 1 }
    role { 'assistant' }
    content { 'Run emitted a monitoring event.' }
    metadata { {} }
  end
end
