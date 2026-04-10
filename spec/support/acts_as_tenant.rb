# frozen_string_literal: true

# Ensure ActsAsTenant is set for all tests
RSpec.configure do |config|
  config.before do
    ActsAsTenant.current_tenant = nil
  end
end
