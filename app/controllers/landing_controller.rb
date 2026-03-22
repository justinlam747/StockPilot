# frozen_string_literal: true

# Public landing page for unauthenticated visitors.
class LandingController < ApplicationController
  skip_before_action :require_clerk_session
  skip_before_action :require_onboarding
  skip_before_action :require_shop_connection
  skip_before_action :set_tenant
  layout 'landing'

  def index; end
end
