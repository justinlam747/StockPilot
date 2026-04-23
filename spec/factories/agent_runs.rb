# frozen_string_literal: true

FactoryBot.define do
  factory :agent_run do
    shop
    agent_kind { 'inventory_monitor' }
    status { 'queued' }
    trigger_source { 'manual' }
    goal { 'Review inventory health and surface actions.' }
    progress_percent { 0 }
    current_phase { 'queued' }
    turns_count { 0 }
    input_payload { {} }
    result_payload { {} }
    metadata { {} }
  end
end
