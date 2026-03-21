# frozen_string_literal: true

module AuthHelpers
  def login_as(shop)
    allow_any_instance_of(ApplicationController).to receive(:current_shop).and_return(shop)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
